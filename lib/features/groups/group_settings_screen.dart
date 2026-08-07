import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/shared_widgets.dart';
import '../auth/auth_provider.dart';
import '../groups/group_provider.dart';

class GroupSettingsScreen extends ConsumerWidget {
  final String groupId;
  const GroupSettingsScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupProvider);
    final groupIdx = groups.indexWhere((g) => g.id == groupId);
    if (groupIdx == -1) {
      return Scaffold(
        appBar: AppBar(title: const Text('Group Settings')),
        body: const Center(child: Text('Group not found')),
      );
    }
    final group = groups[groupIdx];
    final user = ref.watch(authProvider);
    final netBalances = ref.watch(groupNetBalanceProvider(groupId));
    final allUsersAsync = ref.watch(allUsersProvider);
    final allUsers = allUsersAsync.value ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Group Settings')),
      body: ListView(
        children: [
          // ── Group identity ────────────────────────────────────────────
          Container(
            color: Theme.of(context).cardTheme.color,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(group.emoji ?? '👥',
                    style: const TextStyle(fontSize: 48)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.name, style: AppTextStyles.heading2()),
                      if (group.description.isNotEmpty)
                        Text(group.description,
                            style: AppTextStyles.bodySecondary()),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Edit group name coming soon')),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Members ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Group members', style: AppTextStyles.sectionLabel()),
          ),
          const SizedBox(height: 8),

          // Add people + invite link
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: SpendlyColors.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_add_outlined,
                  color: SpendlyColors.primary, size: 20),
            ),
            title: Text('Add people to group',
                style: AppTextStyles.bodyPrimary()),
            onTap: () => _showAddMemberDialog(context, ref, group, allUsers),
          ),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: SpendlyColors.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.link_rounded,
                  color: SpendlyColors.primary, size: 20),
            ),
            title:
                Text('Invite via link', style: AppTextStyles.bodyPrimary()),
            onTap: () {
              Clipboard.setData(
                  const ClipboardData(text: 'https://spendly.app/join/ABC123'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invite link copied! 🔗')),
              );
            },
          ),

          // Member list with balances
          ...group.memberIds.map((memberId) {
            final memberUser = ref.read(userByIdProvider(memberId));
            final balance = netBalances[memberId] ?? 0;
            final isCurrentUser = memberId == user?.id;
            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: UserAvatar(
                  name: memberUser?.name ?? memberId,
                  userId: memberId,
                  size: 44),
              title: Text(
                isCurrentUser
                    ? '${memberUser?.name ?? memberId} (you)'
                    : (memberUser?.name ?? memberId),
                style: AppTextStyles.bodyPrimary()
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: memberUser != null
                  ? Text(memberUser.email,
                      style: AppTextStyles.caption(
                          color: SpendlyColors.neutral500))
                  : null,
              trailing: balance == 0
                  ? null
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          AppFormatters.currency(balance.abs()),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: balance > 0
                                ? SpendlyColors.success
                                : SpendlyColors.danger,
                          ),
                        ),
                        Text(
                          balance > 0 ? 'gets back' : 'owes',
                          style: AppTextStyles.caption(
                            color: balance > 0
                                ? SpendlyColors.success
                                : SpendlyColors.danger,
                          ),
                        ),
                      ],
                    ),
            );
          }),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),

          // ── Advanced Settings ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child:
                Text('Advanced settings', style: AppTextStyles.sectionLabel()),
          ),
          const SizedBox(height: 8),

          // Smart Split toggle
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SpendlyCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_graph_rounded,
                          color: SpendlyColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Simplify group debts',
                                style: AppTextStyles.bodyPrimary().copyWith(
                                    fontWeight: FontWeight.w700)),
                            Text(
                              'Automatically reduces the number of payments needed.',
                              style: AppTextStyles.caption(
                                  color: SpendlyColors.neutral500),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: group.smartSplitEnabled,
                        activeThumbColor: SpendlyColors.primary,
                        onChanged: (v) {
                          ref
                              .read(groupActionProvider)
                              .updateSmartSplit(groupId, v);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Default split type
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SpendlyCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.pie_chart_outline,
                          color: SpendlyColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('Default split type',
                            style: AppTextStyles.bodyPrimary()
                                .copyWith(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<SplitType>(
                    segments: const [
                      ButtonSegment(
                          value: SplitType.equal, label: Text('Equal')),
                      ButtonSegment(
                          value: SplitType.exact, label: Text('Exact')),
                      ButtonSegment(
                          value: SplitType.percentage,
                          label: Text('Percent')),
                    ],
                    selected: {group.defaultSplitType},
                    onSelectionChanged: (s) {
                      ref
                          .read(groupActionProvider)
                          .updateDefaultSplitType(groupId, s.first);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),

          // ── Danger zone ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Danger zone',
                style: AppTextStyles.sectionLabel(
                    color: SpendlyColors.danger)),
          ),
          const SizedBox(height: 8),

          // Leave group
          ListTile(
            leading:
                const Icon(Icons.exit_to_app, color: SpendlyColors.neutral500),
            title: Text('Leave group', style: AppTextStyles.bodyPrimary()),
            onTap: () => _showLeaveDialog(context, ref, group, user?.id),
          ),

          // Delete group (only creator can delete)
          if (group.createdById == user?.id)
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: SpendlyColors.danger),
              title: const Text('Delete group',
                  style: TextStyle(color: SpendlyColors.danger)),
              onTap: () => _showDeleteDialog(context, ref, group),
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showAddMemberDialog(
      BuildContext context, WidgetRef ref, group, allUsers) {
    final availableUsers = (allUsers as List)
        .where((u) => !group.memberIds.contains(u.id))
        .toList();
    if (availableUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All known users are already members')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SpendlyColors.neutral300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Add Members',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              ...availableUsers.map((u) => ListTile(
                    leading: UserAvatar(name: u.name, userId: u.id),
                    title: Text(u.name, overflow: TextOverflow.ellipsis),
                    subtitle: Text(u.email, overflow: TextOverflow.ellipsis),
                    onTap: () {
                      ref.read(groupActionProvider).addMember(group.id, u.id);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${u.name} added!')),
                      );
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _showLeaveDialog(
      BuildContext context, WidgetRef ref, group, String? userId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Group?'),
        content: const Text(
            'You will be removed from this group and lose access to its expenses.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (userId != null) {
                ref.read(groupActionProvider).removeMember(group.id, userId);
              }
              Navigator.pop(ctx);
              context.go('/groups');
            },
            style: TextButton.styleFrom(foregroundColor: SpendlyColors.danger),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Group?'),
        content: Text(
            'This will permanently delete "${group.name}" and all its expenses.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(groupActionProvider).removeGroup(group.id);
              Navigator.pop(ctx);
              context.go('/groups');
            },
            style: TextButton.styleFrom(foregroundColor: SpendlyColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
