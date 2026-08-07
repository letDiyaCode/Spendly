import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/models/enums.dart';
import '../../features/expenses/expense_provider.dart';
import 'personal_expense_provider.dart';

class PersonalExpensesScreen extends ConsumerStatefulWidget {
  const PersonalExpensesScreen({super.key});

  @override
  ConsumerState<PersonalExpensesScreen> createState() =>
      _PersonalExpensesScreenState();
}

class _PersonalExpensesScreenState
    extends ConsumerState<PersonalExpensesScreen> {
  ExpenseCategory? _selectedCategory;
  int? _selectedMonth;
  final _now = DateTime.now();

  // ── Month labels ────────────────────────────────────────────────────────────
  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(filteredPersonalExpensesProvider);
    final monthlyTotal = ref.watch(personalMonthlyTotalProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.go('/personal/add'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Monthly Total Header ─────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: SpendlyColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This Month',
                        style: AppTextStyles.bodySecondary(
                            color: Colors.white.withAlpha(200)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppFormatters.currency(monthlyTotal),
                        style: AppTextStyles.heading1(color: Colors.white),
                      ),
                      Text(
                        AppFormatters.monthYear(_now),
                        style: AppTextStyles.caption(
                            color: Colors.white.withAlpha(180)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.account_balance_wallet_rounded,
                    color: Colors.white38, size: 48),
              ],
            ),
          ),

          // ── Filters ──────────────────────────────────────────────────────
          Container(
            color: cs.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Month filter header row
                Row(
                  children: [
                    Text('Filter by Month',
                        style: AppTextStyles.sectionLabel()),
                    const Spacer(),
                    if (_selectedCategory != null || _selectedMonth != null)
                      GestureDetector(
                        onTap: _clearFilters,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: SpendlyColors.danger.withAlpha(15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Clear',
                            style: AppTextStyles.caption(
                                color: SpendlyColors.danger),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Month chips using reusable widget
                SpendlyFilterChipRow<int>(
                  items: List.generate(12, (i) => i + 1),
                  selected: _selectedMonth,
                  label: (m) => _months[m],
                  onSelect: (m) {
                    setState(() => _selectedMonth = m);
                    ref.read(personalExpenseFilterProvider.notifier).state =
                        PersonalExpenseFilter(
                            month: m, category: _selectedCategory);
                  },
                ),
                const SizedBox(height: 12),
                Text('Filter by Category',
                    style: AppTextStyles.sectionLabel()),
                const SizedBox(height: 8),
                // Category chips using reusable widget
                SpendlyFilterChipRow<ExpenseCategory>(
                  items: ExpenseCategory.values,
                  selected: _selectedCategory,
                  label: (cat) => '${cat.emoji} ${cat.label}',
                  height: 38,
                  onSelect: (cat) {
                    setState(() => _selectedCategory = cat);
                    ref.read(personalExpenseFilterProvider.notifier).state =
                        PersonalExpenseFilter(
                            category: cat, month: _selectedMonth);
                  },
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Expense List ─────────────────────────────────────────────────
          Expanded(
            child: expenses.isEmpty
                ? EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No expenses found',
                    subtitle: 'Add your first personal expense',
                    actionLabel: 'Add Expense',
                    onAction: () => context.go('/personal/add'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: expenses.length,
                    itemBuilder: (context, index) {
                      final e = expenses[index];
                      return Dismissible(
                        key: Key(e.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: SpendlyColors.danger.withAlpha(20),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.delete_outline,
                              color: SpendlyColors.danger),
                        ),
                        confirmDismiss: (_) async {
                          try {
                            await ref.read(expenseActionProvider).deleteExpense(e.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${e.description} deleted'),
                                ),
                              );
                            }
                            return true;
                          } catch (err) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    err.toString().replaceFirst('Bad state: ', ''),
                                  ),
                                ),
                              );
                            }
                            return false;
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SpendlyCard(
                            onTap: () => context.push('/expenses/${e.id}'),
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                // Category icon
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: SpendlyColors.chartColors[
                                            e.category.index %
                                                SpendlyColors.chartColors.length]
                                        .withAlpha(25),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Text(e.category.emoji,
                                        style: const TextStyle(fontSize: 22)),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Title + meta
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.description,
                                        style: tt.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: cs.onSurface),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          if (e.imageUrl != null && e.imageUrl!.isNotEmpty)
                                            SpendlyImage(
                                              source: e.imageUrl!,
                                              width: 34,
                                              height: 34,
                                              fit: BoxFit.cover,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          if (e.imageUrl != null && e.imageUrl!.isNotEmpty)
                                            const SizedBox(width: 8),
                                          // Category badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: SpendlyColors.chartColors[
                                                      e.category.index %
                                                          SpendlyColors
                                                              .chartColors.length]
                                                  .withAlpha(20),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              e.category.label,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: SpendlyColors.chartColors[
                                                    e.category.index %
                                                        SpendlyColors
                                                            .chartColors.length],
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          if (e.paymentMethod != null) ...[
                                            const SizedBox(width: 8),
                                            Icon(Icons.payment_outlined,
                                                size: 12,
                                                color: SpendlyColors.neutral500),
                                            const SizedBox(width: 3),
                                            Flexible(
                                              child: Text(
                                                e.paymentMethod!.label,
                                                style: AppTextStyles.caption(
                                                    color:
                                                        SpendlyColors.neutral600),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                          if (e.imageUrl != null && e.imageUrl!.isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            Text(
                                              'Receipt',
                                              style: AppTextStyles.caption(color: SpendlyColors.primary).copyWith(fontWeight: FontWeight.w700),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Amount + date
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      AppFormatters.currency(e.amount),
                                      style: tt.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: SpendlyColors.danger),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      AppFormatters.relativeDate(e.date),
                                      style: AppTextStyles.caption(
                                          color: SpendlyColors.neutral500),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: (index * 50).ms),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/personal/add'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Expense'),
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = null;
      _selectedMonth = null;
    });
    ref.read(personalExpenseFilterProvider.notifier).state =
        const PersonalExpenseFilter();
  }
}
