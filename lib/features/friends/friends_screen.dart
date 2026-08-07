import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/shared_widgets.dart';
import '../auth/auth_provider.dart';
import '../groups/group_provider.dart';
import '../expenses/expense_provider.dart';
import '../../features/settlements/settlement_provider.dart'; // Keep if used for globalBalancesProvider

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsProvider);
    final balances = ref.watch(globalBalancesProvider);

    // Overall owe / owed
    double totalOwe = 0;
    double totalOwed = 0;
    for (final b in balances.values) {
      if (b < 0) totalOwe += b.abs();
      if (b > 0) totalOwed += b;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            onPressed: () => context.push('/friends/add'),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'Add Friend',
          ),
          TextButton.icon(
            onPressed: () => context.go('/settle'),
            icon: const Icon(Icons.handshake_outlined, size: 18),
            label: const Text('Settle Up'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Summary banner ─────────────────────────────────────────────
          if (totalOwe > 0 || totalOwed > 0)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: Theme.of(context).colorScheme.surface,
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryChip(
                      label: 'You owe',
                      amount: totalOwe,
                      color: SpendlyColors.danger,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryChip(
                      label: 'You are owed',
                      amount: totalOwed,
                      color: SpendlyColors.success,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),

          // ── Friend list ────────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(usersStreamProvider);
                ref.invalidate(expensesStreamProvider);
                ref.invalidate(settlementsStreamProvider);
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: friends.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: EmptyState(
                            icon: Icons.people_outline,
                            title: 'No friends yet',
                            subtitle:
                                'Add a friend directly or join a group to see balances here',
                              actionLabel: 'Add Friend',
                              onAction: () => context.push('/friends/add'),
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: friends.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 72),
                      itemBuilder: (context, i) {
                        final friend = friends[i];
                        final balance = balances[friend.id] ?? 0.0;
                        return _FriendTile(
                          userId: friend.id,
                          name: friend.name,
                          avatarUrl: friend.avatarUrl,
                          isVerified: friend.isVerified,
                          balance: balance,
                          onTap: () => context.push('/friends/${friend.id}'),
                          onSettle: () => context
                              .push('/settle/select?userId=${friend.id}'),
                          onRemind: balance > 0
                              ? () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Reminder sent to ${friend.name.split(' ').first}!'),
                                      backgroundColor: SpendlyColors.primary,
                                    ),
                                  );
                                }
                              : null,
                        ).animate().fadeIn(delay: (i * 60).ms);
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/friends/add'),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add Friend'),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _SummaryChip(
      {required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTextStyles.caption(color: SpendlyColors.neutral600)),
          const SizedBox(height: 2),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: color, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  final String userId;
  final String name;
  final String? avatarUrl;
  final bool isVerified;
  final double balance; // positive: they owe you; negative: you owe them
  final VoidCallback onTap;
  final VoidCallback onSettle;
  final VoidCallback? onRemind;

  const _FriendTile({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.isVerified = false,
    required this.balance,
    required this.onTap,
    required this.onSettle,
    this.onRemind,
  });

  @override
  Widget build(BuildContext context) {
    final isOwed = balance > 0; // they owe us
    final isEven = balance == 0;
    final color = isEven
        ? SpendlyColors.neutral400
        : isOwed
            ? SpendlyColors.success
            : SpendlyColors.danger;

    return ListTile(
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: UserAvatar(
          name: name,
          userId: userId,
          size: 44,
          avatarUrl: avatarUrl,
          isVerified: isVerified),
      title: Text(name,
          style: AppTextStyles.bodyPrimary()
              .copyWith(fontWeight: FontWeight.w700)),
      subtitle: Text(
        isEven
            ? 'Settled up ✓'
            : isOwed
                ? '${name.split(' ').first} owes you'
                : 'You owe ${name.split(' ').first}',
        style: AppTextStyles.caption(color: color),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            isEven ? '₹0.00' : '₹${balance.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: color,
            ),
          ),
          if (!isEven) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onRemind != null)
                  GestureDetector(
                    onTap: onRemind,
                    child: Container(
                      margin: const EdgeInsets.only(top: 4, right: 6),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: SpendlyColors.warning.withAlpha(15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Remind',
                          style: AppTextStyles.caption(
                              color: SpendlyColors.warning)),
                    ),
                  ),
                GestureDetector(
                  onTap: onSettle,
                  child: Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: SpendlyColors.primary.withAlpha(15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Settle',
                        style: AppTextStyles.caption(
                            color: SpendlyColors.primary)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
