import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

import 'features/onboarding/onboarding_screen.dart';
import 'features/inbox/inbox_screen.dart';
import 'features/today/today_plan_screen.dart';
import 'features/habits/habits_screen.dart';
import 'features/habits/add_habit_screen.dart';
import 'features/insights/insights_screen.dart';
import 'features/shell/app_shell.dart';
import 'features/focus/focus_screen.dart';

String _initialRoute() {
  final settings = Hive.box('settings');
  final done = settings.get('onboardingDone', defaultValue: false) as bool;
  return done ? '/inbox' : '/onboarding';
}

final router = GoRouter(
  initialLocation: _initialRoute(),
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),

    // ✅ ShellRoute wraps your main tabs (bottom nav)
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/inbox',
          builder: (context, state) => const InboxScreen(),
        ),
        GoRoute(
          path: '/today',
          builder: (context, state) => const TodayPlanScreen(),
        ),
        GoRoute(
          path: '/habits',
          builder: (context, state) => const HabitsScreen(),
        ),
        GoRoute(
          path: '/insights',
          builder: (context, state) => const InsightsScreen(),
        ),
      ],
    ),

    // Non-tab routes
    GoRoute(
      path: '/addHabit',
      builder: (context, state) => const AddHabitScreen(),
    ),
    GoRoute(
      path: '/focus',
      builder: (context, state) => const FocusScreen(),
    ),
  ],
);
