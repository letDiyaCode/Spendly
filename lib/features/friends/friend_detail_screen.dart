import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/shared_widgets.dart';
import '../auth/auth_provider.dart';
import '../settlements/settlement_provider.dart';
import '../expenses/expense_provider.dart';

class FriendDetailScreen extends ConsumerWidget {
  final String friendUserId;
  const FriendDetailScreen({super.key, required this.friendUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final friendUser = ref.watch(userByIdProvider(friendUserId));
    final balances = ref.watch(friendBalanceProvider);
    final balance = balances[friendUserId] ?? 0.0;
    final settlements = ref.watch(settlementsWithFriendProvider(friendUserId));
    final allExpenses = ref.watch(expenseProvider);

    // Shared expenses with this friend (including personal and group)
    final sharedExpenses = allExpenses.where((e) {
      final involvesFriend = e.participants.contains(friendUserId);
      final involvesMe = user != null && e.participants.contains(user.id);
      return involvesFriend && involvesMe;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final friendName = friendUser?.name ?? friendUserId;
    final isOwed = balance > 0;
    final isEven = balance == 0;
    final balanceColor = isEven
        ? SpendlyColors.neutral500
        : isOwed
            ? SpendlyColors.success
            : SpendlyColors.danger;
    final balanceText = isEven
        ? 'You are settled up ✓'
        : isOwed
            ? '$friendName owes you ₹${balance.abs().toStringAsFixed(2)}'
            : 'You owe $friendName ₹${balance.abs().toStringAsFixed(2)}';

    // Interleave and sort all activity
    final activityItems = <({DateTime date, Widget child})>[];
    
    // Add Expenses
    for (final e in sharedExpenses) {
      final isPaidByMe = e.paidById == user?.id;
      final myShare = e.splitDetails[user?.id] ?? 0;
      final friendShare = e.splitDetails[friendUserId] ?? 0;
      activityItems.add((
        date: e.date,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () {
              if (e.groupId != null) {
                context.push('/groups/${e.groupId}/expense/${e.id}');
              } else {
                context.push('/expenses/${e.id}');
              }
            },
            child: SpendlyCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: SpendlyColors.chartColors[e.category.index % SpendlyColors.chartColors.length].withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(child: Text(e.category.emoji, style: const TextStyle(fontSize: 16))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.description, style: AppTextStyles.bodyPrimary().copyWith(fontWeight: FontWeight.w700)),
                        Text(
                          isPaidByMe
                              ? 'You paid · ${friendName.split(' ').first}\'s share ₹${friendShare.toStringAsFixed(0)}'
                              : '${friendName.split(' ').first} paid · your share ₹${myShare.toStringAsFixed(0)}',
                          style: AppTextStyles.caption(color: SpendlyColors.neutral500),
                        ),
                        if (e.imageUrl != null && e.imageUrl!.isNotEmpty)
                          Text(
                            'Receipt attached',
                            style: AppTextStyles.caption(color: SpendlyColors.primary)
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₹${e.amount.toStringAsFixed(2)}', style: AppTextStyles.bodyPrimary().copyWith(fontWeight: FontWeight.w700)),
                      Text(AppFormatters.shortDate(e.date), style: AppTextStyles.caption(color: SpendlyColors.neutral400)),
                    ],
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, color: SpendlyColors.neutral400, size: 16),
                ],
              ),
            ),
          ),
        ),
      ));
    }

    // Add Settlements
    for (final s in settlements) {
      final isPaying = s.fromUserId == user?.id;
      final isReceiving = s.toUserId == user?.id;
      final needsVerification = s.isPending && isReceiving;

      activityItems.add((
        date: s.createdAt,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SpendlyCard(
            backgroundColor: s.isPending 
                ? (isReceiving ? SpendlyColors.success.withAlpha(10) : SpendlyColors.warning.withAlpha(10))
                : SpendlyColors.success.withAlpha(8),
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: (s.isPending && isReceiving) ? SpendlyColors.success.withAlpha(30) : SpendlyColors.success.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.handshake_rounded, color: SpendlyColors.success, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPaying ? 'You paid ${friendName.split(' ').first}' : '${friendName.split(' ').first} paid you',
                            style: AppTextStyles.bodyPrimary().copyWith(fontWeight: FontWeight.w700),
                          ),
                          StatusBadge(
                            label: s.statusLabel,
                            color: s.statusColor,
                            backgroundColor: s.statusColor.withAlpha(30),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${s.amount.toStringAsFixed(2)}',
                      style: AppTextStyles.bodyPrimary().copyWith(fontWeight: FontWeight.w800, color: SpendlyColors.success),
                    ),
                  ],
                ),
                if (needsVerification) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            try {
                              await ref.read(settlementActionProvider).rejectSettlement(s.id, user!.id);
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString().replaceFirst('Exception: ', '')),
                                ),
                              );
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: SpendlyColors.danger,
                            side: const BorderSide(color: SpendlyColors.danger),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              await ref.read(settlementActionProvider).approveSettlement(s.id, user!.id);
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString().replaceFirst('Exception: ', '')),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SpendlyColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            elevation: 0,
                          ),
                          child: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ));
    }

    activityItems.sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 180,
            actions: [
              IconButton(
                icon: const Icon(Icons.handshake_outlined, color: Colors.white),
                onPressed: () => context.push('/settle/select?userId=$friendUserId'),
                tooltip: 'Settle Up',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: SpendlyColors.primaryGradient,
                ),
                padding: const EdgeInsets.fromLTRB(24, 80, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        UserAvatar(
                            name: friendName,
                            userId: friendUserId,
                            size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(friendName,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800)),
                              Text(
                                friendUser?.email ?? '',
                                style: TextStyle(
                                    color: Colors.white.withAlpha(180),
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      balanceText,
                      style: TextStyle(
                        color: isEven ? Colors.white70 : balanceColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Settle Up button ─────────────────────────────────────────────
          if (!isEven)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: GestureDetector(
                  onTap: () => context.push('/settle/select?userId=$friendUserId'),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: SpendlyColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '💸  Settle Up',
                        style: AppTextStyles.button()
                            .copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── Activity Timeline ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Activity', style: AppTextStyles.sectionLabel()),
            ),
          ),

          if (activityItems.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No shared activity',
                  subtitle: 'Expenses and settlements with this friend will appear here',
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => activityItems[index].child,
                  childCount: activityItems.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/expenses/add', extra: {'friendId': friendUserId}),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Expense'),
      ),
    );
  }
}
