import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  int _indexFromLocation(String location) {
    if (location.startsWith('/today')) return 1;
    if (location.startsWith('/habits')) return 2;
    if (location.startsWith('/insights')) return 3;
    return 0; // inbox
  }

  void _goIndex(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/inbox');
        break;
      case 1:
        context.go('/today');
        break;
      case 2:
        context.go('/habits');
        break;
      case 3:
        context.go('/insights');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _indexFromLocation(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) => _goIndex(context, i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1976D2),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inbox_outlined),
            label: 'Inbox',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.today_outlined),
            label: 'Today',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.checklist_outlined),
            label: 'Habits',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights_outlined),
            label: 'Insights',
          ),
        ],
      ),
    );
  }
}
