import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/shared_widgets.dart';
import '../auth/auth_provider.dart';
import '../groups/group_provider.dart';

class AddFriendScreen extends ConsumerStatefulWidget {
  const AddFriendScreen({super.key});

  @override
  ConsumerState<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends ConsumerState<AddFriendScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider);
    final allUsers = ref.watch(allUsersProvider).value ?? [];
    final friends = ref.watch(friendsProvider);

    final friendIds = friends.map((friend) => friend.id).toSet();
    final candidates = allUsers.where((candidate) {
      if (currentUser == null || candidate.id == currentUser.id) {
        return false;
      }
      if (friendIds.contains(candidate.id)) {
        return false;
      }

      final search = _query.trim().toLowerCase();
      if (search.isEmpty) {
        return true;
      }

      return candidate.name.toLowerCase().contains(search) ||
          candidate.email.toLowerCase().contains(search);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Friend'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(usersStreamProvider);
          await Future.delayed(const Duration(milliseconds: 300));
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Add someone directly by name or email. They will appear in Friends without needing a group first.',
              style: AppTextStyles.bodySecondary(),
            ).animate().fadeIn(),
            const SizedBox(height: 16),
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                labelText: 'Search people',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ).animate().fadeIn(delay: 80.ms),
            const SizedBox(height: 16),
            if (candidates.isEmpty)
              EmptyState(
                icon: Icons.person_add_alt_1_outlined,
                title: 'No matches',
                subtitle: 'Try a different name or email address.',
              )
            else
              ...candidates.map((candidate) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SpendlyCard(
                    onTap: () async {
                      try {
                        await ref.read(friendActionProvider).addFriend(candidate.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${candidate.name} added as a friend')),
                        );
                        context.pop();
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString().replaceFirst('Exception: ', '')),
                            backgroundColor: SpendlyColors.danger,
                          ),
                        );
                      }
                    },
                    child: Row(
                      children: [
                        UserAvatar(
                          name: candidate.name,
                          userId: candidate.id,
                          size: 44,
                          avatarUrl: candidate.avatarUrl,
                          isVerified: candidate.isVerified,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                candidate.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                candidate.email,
                                style: AppTextStyles.caption(color: SpendlyColors.neutral500),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.add_circle_outline_rounded, color: SpendlyColors.primary),
                      ],
                    ),
                  ).animate().fadeIn(delay: 120.ms),
                );
              }),
          ],
        ),
      ),
    );
  }
}