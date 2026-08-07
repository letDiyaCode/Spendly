import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/group.dart';
import '../../core/models/expense.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/models/enums.dart';
import '../../core/models/app_user.dart';
import '../../core/utils/approval_rules.dart';
import '../auth/auth_provider.dart';
import '../expenses/expense_provider.dart';
import '../settlements/settlement_provider.dart';

// ─── Groups ───────────────────────────────────────────────────────────────────

final groupsStreamProvider = StreamProvider<List<Group>>((ref) {
  final user = ref.watch(authProvider);
  if (user == null) return Stream.value([]);
  
  return ref.watch(groupRepositoryProvider).watchGroups(user.id);
});

final groupActionProvider = Provider<GroupActionNotifier>((ref) {
  return GroupActionNotifier(ref);
});

class GroupActionNotifier {
  final Ref _ref;

  GroupActionNotifier(this._ref);

  Future<void> addGroup(Group group) => _ref.read(groupRepositoryProvider).createGroup(group);
  Future<void> updateGroup(Group group) => _ref.read(groupRepositoryProvider).updateGroup(group);
  Future<void> removeGroup(String id) => _ref.read(groupRepositoryProvider).deleteGroup(id);

  Future<void> addMember(String groupId, String userId) async {
    final groups = _ref.read(groupsStreamProvider).value ?? [];
    final group = groups.firstWhere((g) => g.id == groupId);
    if (!group.memberIds.contains(userId)) {
      await _ref.read(groupRepositoryProvider).updateGroup(
          group.copyWith(memberIds: [...group.memberIds, userId]));
    }
  }

  Future<void> removeMember(String groupId, String userId) async {
    final groups = _ref.read(groupsStreamProvider).value ?? [];
    final group = groups.firstWhere((g) => g.id == groupId);
    await _ref.read(groupRepositoryProvider).updateGroup(group.copyWith(
      memberIds: group.memberIds.where((id) => id != userId).toList(),
    ));
  }

  Future<void> updateSmartSplit(String groupId, bool enabled) async {
    final groups = _ref.read(groupsStreamProvider).value ?? [];
    final group = groups.firstWhere((g) => g.id == groupId);
    await _ref.read(groupRepositoryProvider).updateGroup(group.copyWith(smartSplitEnabled: enabled));
  }

  Future<void> updateDefaultSplitType(String groupId, SplitType splitType) async {
    final groups = _ref.read(groupsStreamProvider).value ?? [];
    final group = groups.firstWhere((g) => g.id == groupId);
    await _ref.read(groupRepositoryProvider).updateGroup(group.copyWith(defaultSplitType: splitType));
  }
}

final friendActionProvider = Provider<FriendActionNotifier>((ref) {
  return FriendActionNotifier(ref);
});

class FriendActionNotifier {
  final Ref _ref;

  FriendActionNotifier(this._ref);

  Future<void> addFriend(String friendUserId) async {
    final currentUser = _ref.read(authProvider);
    if (currentUser == null) {
      throw Exception('You must be logged in to add a friend.');
    }
    if (currentUser.id == friendUserId) {
      throw Exception('You cannot add yourself as a friend.');
    }

    final userRepo = _ref.read(userRepositoryProvider);
    final users = await userRepo.getUsers();

    final currentProfile = users.firstWhere(
      (user) => user.id == currentUser.id,
      orElse: () => currentUser.copyWith(),
    );
    final friendProfile = users.firstWhere(
      (user) => user.id == friendUserId,
      orElse: () => throw Exception('Friend not found.'),
    );

    final updatedCurrentIds = <String>{
      ...currentProfile.friendIds,
      friendUserId,
    }.toList();
    final updatedFriendIds = <String>{
      ...friendProfile.friendIds,
      currentUser.id,
    }.toList();

    await userRepo.saveUser(currentProfile.copyWith(friendIds: updatedCurrentIds));
    await userRepo.saveUser(friendProfile.copyWith(friendIds: updatedFriendIds));

    _ref.invalidate(usersStreamProvider);
  }
}

// Keep groupProvider as a list of groups for compatibility
final groupProvider = Provider<List<Group>>((ref) {
  return ref.watch(groupsStreamProvider).value ?? [];
});

// ─── Group Expenses ───────────────────────────────────────────────────────────

// Re-map groupExpenseProvider to utilize the unified expenseProvider
final groupExpenseProvider = Provider<List<Expense>>((ref) {
  return ref.watch(expenseProvider).where((e) => e.type == ExpenseType.group).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
});

// ─── Derived: expenses per group ─────────────────────────────────────────────

final groupExpensesByGroupProvider =
    Provider.family<List<Expense>, String>((ref, groupId) {
  final expenses = ref.watch(expenseProvider);
  return expenses.where((e) => e.groupId == groupId).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
});

// ─── Derived: net balance per group per user ──────────────────────────────────

final groupNetBalanceProvider =
    Provider.family<Map<String, double>, String>((ref, groupId) {
  final expenses = ref.watch(groupExpensesByGroupProvider(groupId));
  final groups = ref.watch(groupProvider);

  final group = groups.firstWhere(
    (g) => g.id == groupId,
    orElse: () => Group(
      id: '', name: '', description: '',
      createdById: '', memberIds: [], createdAt: DateTime.now(),
    ),
  );

  final Map<String, double> net = {for (var id in group.memberIds) id: 0.0};

  for (final expense in expenses) {
    if (!isGroupExpenseApproved(expense, group)) {
      continue;
    }

    for (final entry in expense.splitDetails.entries) {
      final uid = entry.key;
      final amt = entry.value;
      if (uid == expense.paidById) continue;
      net[expense.paidById] = (net[expense.paidById] ?? 0) + amt;
      net[uid] = (net[uid] ?? 0) - amt;
    }
  }

  final settlements = ref.watch(settlementProvider);
  for (final s in settlements.where((s) => s.groupId == groupId && (s.status == SettlementStatus.verified || s.status == SettlementStatus.pendingVerification))) {
    net[s.fromUserId] = (net[s.fromUserId] ?? 0) + s.amount;
    net[s.toUserId] = (net[s.toUserId] ?? 0) - s.amount;
  }

  return net;
});

// ─── Friends (Shared Group Visibility) ────────────────────────────────────────

final friendsProvider = Provider<List<AppUser>>((ref) {
  // Use usersStreamProvider directly so this provider re-fires on every Firestore snapshot.
  final allUsers = ref.watch(usersStreamProvider).value ?? [];
  final groups = ref.watch(groupProvider);
  final currentUser = ref.watch(authProvider);

  if (currentUser == null) return [];

  final currentProfile = ref.watch(userByIdProvider(currentUser.id));

  final sharedUserIds = <String>{};
  sharedUserIds.addAll(currentProfile?.friendIds ?? const []);
  for (final group in groups) {
    if (group.memberIds.contains(currentUser.id)) {
      sharedUserIds.addAll(group.memberIds);
    }
  }

  sharedUserIds.remove(currentUser.id); // remove self

  return allUsers.where((u) => sharedUserIds.contains(u.id)).toList();
});
