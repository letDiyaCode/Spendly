import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/settlement.dart';
import '../../core/models/enums.dart';
import '../../core/utils/debt_simplifier.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/utils/approval_rules.dart';
import '../auth/auth_provider.dart';
import '../groups/group_provider.dart';
import '../expenses/expense_provider.dart';
import '../../core/models/group.dart';

// ─── Settlement Notifier ──────────────────────────────────────────────────────

final settlementsStreamProvider = StreamProvider<List<Settlement>>((ref) {
  final user = ref.watch(authProvider);
  if (user == null) return Stream.value([]);
  
  return ref.watch(settlementRepositoryProvider).watchUserSettlements(user.id);
});

final settlementActionProvider = Provider<SettlementActionNotifier>((ref) {
  return SettlementActionNotifier(ref);
});

class SettlementActionNotifier {
  final Ref _ref;
  static const int _maxVerificationAttempts = 3;
  static const double _epsilon = 0.01;

  SettlementActionNotifier(this._ref);

  Future<void> createSettlement(Settlement settlement, {dynamic imageFile}) async {
    final currentUser = _ref.read(authProvider);
    if (currentUser == null) {
      throw Exception('You must be logged in to create a settlement.');
    }

    if (settlement.amount <= _epsilon) {
      throw Exception('Settlement amount must be greater than zero.');
    }

    if (settlement.fromUserId == settlement.toUserId) {
      throw Exception('Invalid settlement: payer and payee cannot be the same user.');
    }

    final outstanding = _outstandingAmountForCurrentUser(
      settlement: settlement,
      currentUserId: currentUser.id,
    );
    if (outstanding <= _epsilon) {
      throw Exception('No pending balance remains for this settlement.');
    }
    if (settlement.amount > outstanding + _epsilon) {
      throw Exception(
        'Settlement amount exceeds pending balance (max ${outstanding.toStringAsFixed(2)}).',
      );
    }

    final all = await _ref
        .read(settlementRepositoryProvider)
        .getUserSettlements(currentUser.id);
    final related = all.where((existing) => _isSameConversation(existing, settlement));

    final hasPending = related.any(
      (existing) => existing.status == SettlementStatus.pendingVerification,
    );
    if (hasPending) {
      throw Exception('A pending settlement request already exists for this balance.');
    }

    // If payee is recording that someone already paid them, auto-verify.
    // This avoids unnecessary self-approval for receiver-created incoming settlements.
    final isPersonalSettlement = settlement.groupId == null || settlement.groupId!.isEmpty;
    final createdByPayee = currentUser.id == settlement.toUserId;
    final shouldAutoVerify = isPersonalSettlement && createdByPayee;

    final pendingSettlement = settlement.copyWith(
      status: shouldAutoVerify
          ? SettlementStatus.verified
          : SettlementStatus.pendingVerification,
      approvals: shouldAutoVerify
          ? [
              ...settlement.approvals.where((id) => id != currentUser.id),
              currentUser.id,
            ]
          : settlement.approvals,
      verificationAttempts: settlement.verificationAttempts,
    );

    await _ref
        .read(settlementRepositoryProvider)
        .addSettlement(pendingSettlement, imageFile: imageFile);

    // If a new verified settlement is recorded, invalidate older pending ones
    // in the same conversation to prevent duplicate approval/rejection actions.
    if (pendingSettlement.status == SettlementStatus.verified) {
      await _closeSupersededPending(
        all,
        reference: pendingSettlement,
      );
    }

    _ref.invalidate(settlementsStreamProvider);
  }

  Future<void> settleUp(String friendId, double amount) async {
    final user = _ref.read(authProvider);
    if (user == null) return;

    final settlement = Settlement(
      id: const Uuid().v4(),
      fromUserId: user.id,
      toUserId: friendId,
      amount: amount,
      status: SettlementStatus.pendingVerification,
      createdAt: DateTime.now(),
    );

    await _ref.read(settlementRepositoryProvider).addSettlement(settlement);
    _ref.invalidate(settlementsStreamProvider);
  }
  
  Future<void> approveSettlement(String id, String userId) async {
    final s = await _ref.read(settlementRepositoryProvider).getSettlementById(id);
    if (s == null) {
      throw Exception('Settlement not found.');
    }
    if (s.status == SettlementStatus.verified) return;
    if (s.status == SettlementStatus.rejected) {
      throw Exception('Rejected settlement cannot be approved. Please submit a new request.');
    }
    if (s.fromUserId == userId) {
      throw Exception('Payer cannot self-approve settlement.');
    }
    if (s.approvals.contains(userId)) return;
    if (s.rejections.contains(userId)) {
      throw Exception('You already rejected this settlement. Ask payer to resubmit.');
    }

    final newApprovals = [...s.approvals, userId];
    final newRejections = s.rejections.where((r) => r != userId).toList();
    final requiredApprovals = _requiredApprovalsFor(s);
    final isFullyVerified = newApprovals.length >= requiredApprovals;

    final all = await _ref
        .read(settlementRepositoryProvider)
        .getUserSettlements(userId);
    final hasSupersedingVerified = all.any((existing) {
      if (!_isSameConversation(existing, s)) return false;
      if (existing.status != SettlementStatus.verified) return false;
      if (existing.id == s.id) return false;
      return existing.createdAt.isAfter(s.createdAt) && existing.amount + _epsilon >= s.amount;
    });

    if (hasSupersedingVerified) {
      await _ref.read(settlementRepositoryProvider).updateStatus(
        s.id,
        SettlementStatus.rejected,
        rejectionReason: 'Superseded by an already verified settlement.',
        verificationAttempts: s.verificationAttempts,
        approvals: s.approvals,
        rejections: [...s.rejections, userId],
      );
      _ref.invalidate(settlementsStreamProvider);
      throw Exception('This request is outdated because the balance is already settled.');
    }

    if (s.groupId == null && userId != s.toUserId) {
      throw Exception('Only the payee can verify this settlement.');
    }

    await _ref.read(settlementRepositoryProvider).updateStatus(
      id, 
      isFullyVerified ? SettlementStatus.verified : s.status,
      verificationAttempts: s.verificationAttempts,
      approvals: newApprovals,
      rejections: newRejections,
    );

    if (isFullyVerified) {
      final refreshed = await _ref
          .read(settlementRepositoryProvider)
          .getSettlementById(id);
      if (refreshed != null) {
        final allForUser = await _ref
            .read(settlementRepositoryProvider)
            .getUserSettlements(userId);
        await _closeSupersededPending(allForUser, reference: refreshed);
      }
    }

    _ref.invalidate(settlementsStreamProvider);
  }

  Future<void> rejectSettlement(String id, String userId, {String? reason}) async {
    final s = await _ref.read(settlementRepositoryProvider).getSettlementById(id);
    if (s == null) {
      throw Exception('Settlement not found.');
    }
    if (s.status == SettlementStatus.verified) {
      throw Exception('Verified settlement cannot be rejected.');
    }
    if (s.fromUserId == userId) {
      throw Exception('Payer cannot reject own settlement request.');
    }
    if (s.verificationAttempts >= _maxVerificationAttempts) {
      throw Exception('Maximum verification retries reached. Please create a new settlement request.');
    }

    if (s.groupId == null && userId != s.toUserId) {
      throw Exception('Only the payee can reject this settlement.');
    }

    final newRejections = [...s.rejections, userId];
    final newApprovals = s.approvals.where((a) => a != userId).toList();
    final nextAttempts = s.verificationAttempts + 1;

    await _ref.read(settlementRepositoryProvider).updateStatus(
      id, 
      SettlementStatus.rejected,
      rejectionReason: reason,
      verificationAttempts: nextAttempts,
      approvals: newApprovals,
      rejections: newRejections,
    );
    _ref.invalidate(settlementsStreamProvider);
  }

  Future<void> updateTransactionId(String id, String transactionId) async {
    await _ref.read(settlementRepositoryProvider).updateTransactionId(id, transactionId);
    _ref.invalidate(settlementsStreamProvider);
  }

  int _requiredApprovalsFor(Settlement settlement) {
    if (settlement.groupId == null || settlement.groupId!.isEmpty) {
      return 1;
    }

    final groups = _ref.read(groupProvider);
    final group = groups.where((g) => g.id == settlement.groupId).firstOrNull;
    if (group == null) {
      return 1;
    }

    final sixtyPercent = (group.memberIds.length * 0.6).ceil();
    return sixtyPercent < 1 ? 1 : sixtyPercent;
  }

  bool _isSameConversation(Settlement a, Settlement b) {
    final sameDirection = a.fromUserId == b.fromUserId && a.toUserId == b.toUserId;
    final reverseDirection = a.fromUserId == b.toUserId && a.toUserId == b.fromUserId;
    final groupA = (a.groupId ?? '').trim();
    final groupB = (b.groupId ?? '').trim();
    return (sameDirection || reverseDirection) && groupA == groupB;
  }

  double _outstandingAmountForCurrentUser({
    required Settlement settlement,
    required String currentUserId,
  }) {
    final isCurrentUserPayer = settlement.fromUserId == currentUserId;
    final isCurrentUserPayee = settlement.toUserId == currentUserId;
    if (!isCurrentUserPayer && !isCurrentUserPayee) {
      throw Exception('You can only create settlements for your own balances.');
    }

    final friendId = isCurrentUserPayer ? settlement.toUserId : settlement.fromUserId;
    final normalizedGroupId = (settlement.groupId ?? '').trim();

    double balance;
    if (normalizedGroupId.isEmpty) {
      final balances = _ref.read(globalBalancesProvider);
      balance = balances[friendId] ?? 0.0;
    } else {
      final groupBalances = _ref.read(groupBalancesWithFriendProvider(friendId));
      final record = groupBalances.where((g) => g['groupId'] == normalizedGroupId).firstOrNull;
      balance = (record?['balance'] as double?) ?? 0.0;
    }

    if (isCurrentUserPayer) {
      if (balance >= -_epsilon) {
        return 0.0;
      }
      return -balance;
    }

    if (balance <= _epsilon) {
      return 0.0;
    }
    return balance;
  }

  Future<void> _closeSupersededPending(
    List<Settlement> all, {
    required Settlement reference,
  }) async {
    final candidates = all.where((existing) {
      if (existing.id == reference.id) return false;
      if (existing.status != SettlementStatus.pendingVerification) return false;
      if (!_isSameConversation(existing, reference)) return false;
      return existing.createdAt.isBefore(reference.createdAt) ||
          existing.createdAt.isAtSameMomentAs(reference.createdAt);
    });

    for (final old in candidates) {
      await _ref.read(settlementRepositoryProvider).updateStatus(
        old.id,
        SettlementStatus.rejected,
        rejectionReason: 'Superseded by a completed settlement.',
        verificationAttempts: old.verificationAttempts,
        approvals: old.approvals,
        rejections: old.rejections,
      );
    }
  }
}

// Keep settlementProvider as a list of settlements for compatibility
final settlementProvider = Provider<List<Settlement>>((ref) {
  return ref.watch(settlementsStreamProvider).value ?? [];
});

// ─── Filters & Selectors ──────────────────────────────────────────────────────

final userSettlementsProvider = Provider<List<Settlement>>((ref) {
  final user = ref.watch(authProvider);
  final settlements = ref.watch(settlementProvider);
  if (user == null) return [];
  return settlements.where((s) => s.fromUserId == user.id || s.toUserId == user.id).toList();
});

final pendingSettlementsProvider = Provider<List<Settlement>>((ref) {
  final settlements = ref.watch(userSettlementsProvider);
  return settlements.where((s) => s.status == SettlementStatus.pendingVerification).toList();
});

final settlementsWithFriendProvider = Provider.family<List<Settlement>, String>((ref, friendUserId) {
  final settlements = ref.watch(userSettlementsProvider);
  return settlements.where((s) => s.fromUserId == friendUserId || s.toUserId == friendUserId).toList();
});

// ─── Debt Simplification ─────────────────────────────────────────────────────

final debtSuggestionsProvider = Provider.family<List<DebtSuggestion>, String>((ref, groupId) {
  final expenses = ref.watch(groupExpensesProvider(groupId));
  final groups = ref.watch(groupProvider);
  final group = groups.firstWhere((g) => g.id == groupId, orElse: () => Group(id: '', name: '', description: '', createdById: '', memberIds: [], createdAt: DateTime.now()));
  return DebtSimplifier.simplify(expenses, group.memberIds);
});

// ─── Unified Balances (Implementation of globalBalancesProvider) ───────────────────────

final globalBalancesProvider = Provider<Map<String, double>>((ref) {
  final user = ref.watch(authProvider);
  if (user == null) return {};

  final expenses = ref.watch(expenseProvider);
  final groups = ref.watch(groupProvider);
  final settlements = ref.watch(userSettlementsProvider).where((s) => s.isVerified).toList();

  final Map<String, double> balances = {};

  // 1. Process Expenses
  for (final e in expenses) {
    if (e.type == ExpenseType.group) {
      final group = groups.where((g) => g.id == e.groupId).firstOrNull;
      if (!isGroupExpenseApproved(e, group)) continue;
    }

    if (e.paidById == user.id) {
      // We paid. For each other participant, they owe us their share.
      for (final entry in e.splitDetails.entries) {
        if (entry.key == user.id) continue;
        balances[entry.key] = (balances[entry.key] ?? 0.0) + entry.value;
      }
    } else if (e.participants.contains(user.id)) {
      // Someone else paid. We owe the payer our share.
      final myShare = e.splitDetails[user.id] ?? 0.0;
      if (myShare > 0) {
        balances[e.paidById] = (balances[e.paidById] ?? 0.0) - myShare;
      }
    }
  }

  // 2. Process Verified Settlements
  for (final s in settlements) {
    if (s.fromUserId == user.id) {
      // We paid someone. Our debt to them decreases or their debt to us increases.
      balances[s.toUserId] = (balances[s.toUserId] ?? 0.0) + s.amount;
    } else if (s.toUserId == user.id) {
      // Someone paid us. Our debt to them increases or their debt to us decreases.
      balances[s.fromUserId] = (balances[s.fromUserId] ?? 0.0) - s.amount;
    }
  }

  return balances;
});

final overallBalanceProvider = Provider<Map<String, double>>((ref) {
  final balancesByFriend = ref.watch(globalBalancesProvider);
  
  double owe = 0.0;
  double owed = 0.0;

  for (final amount in balancesByFriend.values) {
    if (amount > 0) {
      owed += amount;
    } else if (amount < 0) {
      owe += amount.abs();
    }
  }

  return {'owe': owe, 'owed': owed, 'net': owed - owe};
});

final friendBalanceProvider = Provider<Map<String, double>>((ref) {
  return ref.watch(globalBalancesProvider);
});

/// Per-group balance breakdown between current user and a specific friend.
/// Returns a list of { 'groupId': String, 'groupName': String, 'balance': double }
/// Positive balance = friend owes you, negative = you owe friend.
final groupBalancesWithFriendProvider =
    Provider.family<List<Map<String, dynamic>>, String>((ref, friendUserId) {
  final user = ref.watch(authProvider);
  if (user == null) return [];

  final expenses = ref.watch(expenseProvider);
  final groups = ref.watch(groupProvider);
  final settlements = ref.watch(userSettlementsProvider).where((s) => s.isVerified).toList();

  // Collect all groupIds from shared expenses
  final groupBalances = <String, double>{};
  double personalBalance = 0.0;

  for (final e in expenses) {
    final involvesMe = e.participants.contains(user.id);
    final involvesFriend = e.participants.contains(friendUserId);
    if (!involvesMe || !involvesFriend) continue;

    final key = e.groupId ?? '__personal__';

    double delta = 0.0;
    if (e.paidById == user.id) {
      delta = e.splitDetails[friendUserId] ?? 0.0;
    } else if (e.paidById == friendUserId) {
      delta = -(e.splitDetails[user.id] ?? 0.0);
    }

    if (key == '__personal__') {
      personalBalance += delta;
    } else {
      groupBalances[key] = (groupBalances[key] ?? 0.0) + delta;
    }
  }

  // Factor in verified settlements between these two users
  for (final s in settlements) {
    final betweenUs = (s.fromUserId == user.id && s.toUserId == friendUserId) ||
        (s.fromUserId == friendUserId && s.toUserId == user.id);
    if (!betweenUs) continue;

    final delta = s.fromUserId == user.id ? s.amount : -s.amount;
    // Apply to personal bucket (settlements are user-level)
    personalBalance += delta;
  }

  final result = <Map<String, dynamic>>[];

  // Add group entries
  for (final entry in groupBalances.entries) {
    if (entry.value.abs() < 0.01) continue;
    final group = groups.where((g) => g.id == entry.key).firstOrNull;
    result.add({
      'groupId': entry.key,
      'groupName': group?.name ?? 'Unknown Group',
      'emoji': group?.emoji ?? '👥',
      'balance': entry.value,
    });
  }

  // Add personal entry if non-zero
  if (personalBalance.abs() >= 0.01) {
    result.add({
      'groupId': '__personal__',
      'groupName': 'Non-group expenses',
      'emoji': '💸',
      'balance': personalBalance,
    });
  }

  return result;
});
