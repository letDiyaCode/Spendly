import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/approval_rules.dart';
import '../../core/widgets/shared_widgets.dart';
import '../auth/auth_provider.dart';
import 'group_provider.dart';
import '../expenses/expense_provider.dart';
import '../settlements/settlement_provider.dart';

class GroupDetailScreen extends ConsumerWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupProvider);
    final groupIdx = groups.indexWhere((g) => g.id == groupId);
    if (groupIdx == -1) {
      return Scaffold(
        appBar: AppBar(title: const Text('Group')),
        body: const Center(child: Text('Group not found')),
      );
    }
    final group = groups[groupIdx];
    final expenses = ref.watch(groupExpensesByGroupProvider(groupId));
    final netBalances = ref.watch(groupNetBalanceProvider(groupId));
    final suggestions = ref.watch(debtSuggestionsProvider(groupId));
    final user = ref.watch(authProvider);
    final requiredApprovals = requiredApprovalsForGroup(group);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(expensesStreamProvider);
          ref.invalidate(settlementsStreamProvider);
          ref.invalidate(groupsStreamProvider);
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            pinned: true,
            expandedHeight: 160,
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
                    Text(
                      '${group.emoji ?? ''} ${group.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${group.memberIds.length} members · ${expenses.length} expenses',
                      style: TextStyle(color: Colors.white.withAlpha(180)),
                    ),
                  ],
                ),
              ),
              title: null,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                onPressed: () => context.push('/groups/$groupId/settings'),
                tooltip: 'Group Settings',
              ),
            ],
          ),

          // Member Balances
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Member Balances'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: group.memberIds.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final memberId = group.memberIds[i];
                        final memberUser = ref.read(userByIdProvider(memberId));
                        final balance = netBalances[memberId] ?? 0;
                        final isCurrentUser = memberId == user?.id;
                        return Container(
                          width: 110,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardTheme.color,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(8),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isCurrentUser
                                    ? 'You'
                                    : (memberUser?.name.split(' ').first ??
                                        memberId.substring(0, 2)),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              Text(
                                balance == 0
                                    ? 'Settled'
                                    : AppFormatters.currency(balance.abs()),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: balance > 0
                                      ? SpendlyColors.success
                                      : balance < 0
                                          ? SpendlyColors.danger
                                          : SpendlyColors.neutral500,
                                ),
                              ),
                              Text(
                                balance > 0
                                    ? 'gets back'
                                    : balance < 0
                                        ? 'owes'
                                        : '',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: SpendlyColors.neutral500,
                                        fontSize: 10),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Smart Debt Simplification
          if (suggestions.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: '💡 Smart Settle Up'),
                    const SizedBox(height: 8),
                    ...suggestions.map((s) {
                      final fromUser = ref.read(userByIdProvider(s.fromUserId));
                      final toUser = ref.read(userByIdProvider(s.toUserId));
                      final isCurrentUserPayer = s.fromUserId == user?.id;
                      final isCurrentUserPayee = s.toUserId == user?.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: () {
                            if (isCurrentUserPayer) {
                              context.push('/settle?userId=${s.toUserId}');
                            } else if (isCurrentUserPayee) {
                              context.push('/settle?userId=${s.fromUserId}');
                            } else {
                              context.push('/settle?userId=${s.toUserId}');
                            }
                          },
                          child: SpendlyCard(
                            backgroundColor: isCurrentUserPayer
                                ? SpendlyColors.warning.withAlpha(10)
                                : isCurrentUserPayee
                                    ? SpendlyColors.success.withAlpha(10)
                                    : null,
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                UserAvatar(
                                  name: fromUser?.name ?? s.fromUserId,
                                  userId: s.fromUserId,
                                  size: 36,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${isCurrentUserPayer ? 'You' : (fromUser?.name.split(' ').first ?? '?')} → ${isCurrentUserPayee ? 'You' : (toUser?.name.split(' ').first ?? '?')}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        'Direct payment',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                color: SpendlyColors.neutral500),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  AppFormatters.currency(s.amount),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: isCurrentUserPayer
                                        ? SpendlyColors.danger
                                        : SpendlyColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => context.push('/settle'),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: SpendlyColors.primary, width: 1.5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'View All Settlements →',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: SpendlyColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Expense Timeline
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SectionHeader(
                title: 'Expenses',
                actionLabel: 'Add',
                onAction: () => context.push('/groups/$groupId/add-expense'),
              ),
            ),
          ),
          if (expenses.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: EmptyState(
                  icon: Icons.receipt_outlined,
                  title: 'No expenses yet',
                  subtitle: 'Add the first expense to this group',
                  actionLabel: 'Add Expense',
                  onAction: () => context.push('/groups/$groupId/add-expense'),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final expense = expenses[index];
                    final paidByUser =
                        ref.read(userByIdProvider(expense.paidById));
                    final isPaidByMe = expense.paidById == user?.id;
                    final myShare = expense.splitDetails[user?.id] ?? 0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () => context.push(
                            '/groups/$groupId/expense/${expense.id}'),
                        child: SpendlyCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: SpendlyColors.chartColors[
                                              expense.category.index %
                                                  SpendlyColors.chartColors.length]
                                          .withAlpha(25),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(expense.category.emoji,
                                          style: const TextStyle(fontSize: 18)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          expense.description,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          isPaidByMe
                                              ? 'Paid by you'
                                              : 'Paid by ${paidByUser?.name.split(' ').first ?? '?'}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                  color: SpendlyColors.neutral500),
                                        ),
                                        if (expense.imageUrl != null && expense.imageUrl!.isNotEmpty)
                                          Text(
                                            'Receipt attached',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: SpendlyColors.primary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        AppFormatters.currency(expense.amount),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(fontWeight: FontWeight.w700),
                                      ),
                                      if (!isPaidByMe)
                                        Text(
                                          'Your share: ${AppFormatters.currency(myShare)}',
                                          style: const TextStyle(
                                            color: SpendlyColors.danger,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Text(
                                    AppFormatters.shortDate(expense.date),
                                    style: AppTextStyles.caption(color: SpendlyColors.neutral400),
                                  ),
                                  const Spacer(),
                                  if (expense.approvals.isNotEmpty) ...[
                                    Icon(Icons.check_circle_rounded, size: 14, color: SpendlyColors.success.withAlpha(180)),
                                    const SizedBox(width: 4),
                                    Text('${expense.approvals.length}/$requiredApprovals', style: AppTextStyles.caption(color: SpendlyColors.success)),
                                    const SizedBox(width: 8),
                                  ],
                                  if (expense.rejections.isNotEmpty) ...[
                                    Icon(Icons.cancel_rounded, size: 14, color: SpendlyColors.danger.withAlpha(180)),
                                    const SizedBox(width: 4),
                                    Text('${expense.rejections.length}/$requiredApprovals', style: AppTextStyles.caption(color: SpendlyColors.danger)),
                                    const SizedBox(width: 8),
                                  ],
                                  if (expense.type == ExpenseType.group && expense.approvals.length < requiredApprovals && expense.rejections.length < requiredApprovals) ...[
                                    Text(
                                      'Needs $requiredApprovals approvals',
                                      style: AppTextStyles.caption(color: SpendlyColors.neutral500),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  if (!expense.approvals.contains(user?.id) && !expense.rejections.contains(user?.id) && !isPaidByMe) ...[
                                    TextButton(
                                      onPressed: () => ref.read(expenseActionProvider).rejectExpense(expense.id, user!.id),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        foregroundColor: SpendlyColors.danger,
                                      ),
                                      child: const Text('Reject', style: TextStyle(fontSize: 11)),
                                    ),
                                    const SizedBox(width: 4),
                                    TextButton(
                                      onPressed: () => ref.read(expenseActionProvider).approveExpense(expense.id, user!.id),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        foregroundColor: SpendlyColors.success,
                                      ),
                                      child: const Text('Approve', style: TextStyle(fontSize: 11)),
                                    ),
                                  ] else if (expense.approvals.contains(user?.id)) ...[
                                    const Text('✓ Approved', style: TextStyle(color: SpendlyColors.success, fontSize: 11, fontWeight: FontWeight.w600)),
                                  ] else if (expense.rejections.contains(user?.id)) ...[
                                    const Text('✗ Rejected', style: TextStyle(color: SpendlyColors.danger, fontSize: 11, fontWeight: FontWeight.w600)),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: (index * 60).ms),
                    );
                  },
                  childCount: expenses.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
        ),   // CustomScrollView
      ),     // RefreshIndicator
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/groups/$groupId/add-expense'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Expense'),
      ),
    );
  }
}

