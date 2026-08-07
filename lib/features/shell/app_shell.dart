import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  DateTime? _lastBackPress;

  int _calculateIndex(String location) {
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/groups')) return 1;
    if (location.startsWith('/friends')) return 2;
    if (location.startsWith('/activity')) return 3;
    if (location.startsWith('/account')) return 4;
    // Secondary routes (personal, analytics, settlements, settle) → Account
    return 4;
  }

  Future<bool> _onPopInvoked(BuildContext context, int currentIndex) async {

    // If not on home tab, go to home tab instead of exiting
    if (currentIndex != 0) {
      context.go('/home');
      return false;
    }

    // On home tab: double-back to exit
    final now = DateTime.now();
    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Press back again to exit'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }

    // Second press within 2 seconds → exit
    SystemNavigator.pop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _calculateIndex(location);
    final cs = Theme.of(context).colorScheme;
    final canRoutePop = GoRouter.of(context).canPop();

    return PopScope(
      canPop: canRoutePop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _onPopInvoked(context, currentIndex);
      },
      child: Scaffold(
        body: widget.child,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: NavigationBar(
            selectedIndex: currentIndex,
            backgroundColor: cs.surface,
            indicatorColor: SpendlyColors.primary.withAlpha(25),
            onDestinationSelected: (index) {
              switch (index) {
                case 0:
                  context.go('/home');
                  break;
                case 1:
                  context.go('/groups');
                  break;
                case 2:
                  context.go('/friends');
                  break;
                case 3:
                  context.go('/activity');
                  break;
                case 4:
                  context.go('/account');
                  break;
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.group_outlined),
                selectedIcon: Icon(Icons.group_rounded),
                label: 'Groups',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_outline_rounded),
                selectedIcon: Icon(Icons.people_rounded),
                label: 'Friends',
              ),
              NavigationDestination(
                icon: Icon(Icons.view_timeline_outlined),
                selectedIcon: Icon(Icons.view_timeline_rounded),
                label: 'Activity',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Account',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
