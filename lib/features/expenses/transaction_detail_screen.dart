import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/models/expense.dart';
import '../auth/auth_provider.dart';
import '../groups/group_provider.dart';
import '../comments/comment_sheet.dart';
import '../comments/comment_provider.dart';
import 'expense_provider.dart';

/// Full-detail view for a single expense.
/// Route: /groups/:id/expense/:expenseId or similar
class TransactionDetailScreen extends ConsumerWidget {
  final String? groupId;
  final String expenseId;

  const TransactionDetailScreen({
    super.key,
    this.groupId,
    required this.expenseId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expenseProvider);
    final expenseIdx = expenses.indexWhere((e) => e.id == expenseId);
    
    if (expenseIdx == -1) {
      return Scaffold(
        appBar: AppBar(title: const Text('Expense')),
        body: const Center(child: Text('Expense not found')),
      );
    }
    
    final expense = expenses[expenseIdx];
    final group = expense.groupId != null
      ? ref.watch(groupProvider).where((g) => g.id == expense.groupId).firstOrNull
      : null;
    
    final currentUser = ref.watch(authProvider);
    final comments = ref.watch(commentsForTargetProvider(expenseId));

    String userName(String uid) {
      if (uid == currentUser?.id) return 'You';
      final u = ref.watch(userByIdProvider(uid));
      return u?.name ?? uid;
    }

    final paidByName = userName(expense.paidById);
    final isPaidByMe = expense.paidById == currentUser?.id;
    final myShare = expense.splitDetails[currentUser?.id] ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(expense.description),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () {
              if (expense.groupId != null) {
                context.push('/groups/${expense.groupId}/add-expense', extra: {'expenseId': expense.id});
              } else {
                context.push('/personal/add', extra: {'expenseId': expense.id});
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: SpendlyColors.danger),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context, ref, expense),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                SpendlyCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(expense.category.emoji, style: const TextStyle(fontSize: 40)),
                      const SizedBox(height: 8),
                      Text(expense.description, style: AppTextStyles.heading2(), textAlign: TextAlign.center),
                      if (group != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(group.emoji ?? '👥', style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 4),
                              Text(group.name, style: AppTextStyles.caption(color: SpendlyColors.neutral500)),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        AppFormatters.currency(expense.amount),
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: SpendlyColors.primary, letterSpacing: -1),
                      ),
                      const SizedBox(height: 4),
                      Text('Added on ${AppFormatters.fullDate(expense.date)}', style: AppTextStyles.caption(color: SpendlyColors.neutral400)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Paid By
                SpendlyCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      UserAvatar(name: paidByName, userId: expense.paidById, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$paidByName paid', style: AppTextStyles.bodyPrimary().copyWith(fontWeight: FontWeight.w700)),
                            Text(AppFormatters.currency(expense.amount), style: AppTextStyles.caption(color: SpendlyColors.neutral500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Split breakdown
                SpendlyCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Split details', style: AppTextStyles.sectionLabel()),
                      const SizedBox(height: 12),
                      ...expense.splitDetails.entries.map((entry) {
                        final memberId = entry.key;
                        final share = entry.value;
                        final name = userName(memberId);
                        final isPayer = memberId == expense.paidById;
                        final isMe = memberId == currentUser?.id;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              UserAvatar(name: name, userId: memberId, size: 32),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: AppTextStyles.bodyPrimary().copyWith(fontWeight: FontWeight.w600)),
                                    Text(
                                      isPayer ? 'Paid the bill' : '${isMe ? 'You owe' : '$name owes'} ${AppFormatters.currency(share)}',
                                      style: AppTextStyles.caption(color: isPayer ? SpendlyColors.success : SpendlyColors.danger),
                                    ),
                                  ],
                                ),
                              ),
                              Text(AppFormatters.currency(share), style: TextStyle(fontWeight: FontWeight.w700, color: isPayer ? SpendlyColors.neutral700 : SpendlyColors.danger)),
                            ],
                          ),
                        );
                      }),
                      const Divider(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isPaidByMe ? SpendlyColors.success.withAlpha(15) : SpendlyColors.danger.withAlpha(15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(isPaidByMe ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: isPaidByMe ? SpendlyColors.success : SpendlyColors.danger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isPaidByMe
                                    ? 'You paid ${AppFormatters.currency(expense.amount)} · you get back ${AppFormatters.currency(expense.amount - myShare)}'
                                    : '$paidByName paid · you owe ${AppFormatters.currency(myShare)}',
                                style: TextStyle(fontWeight: FontWeight.w700, color: isPaidByMe ? SpendlyColors.success : SpendlyColors.danger, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                if (expense.imageUrl != null && expense.imageUrl!.isNotEmpty) ...[
                   Text('Receipt', style: AppTextStyles.sectionLabel()),
                   const SizedBox(height: 10),
                   SpendlyImage(
                     source: expense.imageUrl!,
                     height: 220,
                     width: double.infinity,
                     fit: BoxFit.cover,
                     borderRadius: BorderRadius.circular(14),
                   ),
                   const SizedBox(height: 12),
                ],

                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('Comments', style: AppTextStyles.sectionLabel()),
                    const Spacer(),
                    Text('${comments.length}', style: AppTextStyles.caption(color: SpendlyColors.neutral400)),
                  ],
                ),
                const SizedBox(height: 8),
                if (comments.isEmpty)
                   Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Center(child: Text('No comments yet.', style: AppTextStyles.caption(color: SpendlyColors.neutral400))))
                else
                  ...comments.map((c) => _CommentTile(comment: c, userName: userName(c.userId))),
                
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCommentsSheet(context, ref, expenseId, 'expense'),
        icon: const Icon(Icons.chat_bubble_outline_rounded),
        label: const Text('Add Comment'),
        backgroundColor: SpendlyColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Expense expense) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text('Delete "${expense.description}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              try {
                await ref.read(expenseActionProvider).deleteExpense(expense.id);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  context.pop();
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: SpendlyColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final dynamic comment;
  final String userName;

  const _CommentTile({required this.comment, required this.userName});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(name: userName, userId: comment.userId, size: 32),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: AppTextStyles.caption(color: cs.onSurfaceVariant)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    comment.message,
                    style: AppTextStyles.bodySecondary(color: cs.onSurface),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
