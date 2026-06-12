import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/utils/date_keys.dart';
import '../../core/utils/inbox_types.dart';
import '../../core/utils/week_utils.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inboxBox = Hive.box('inbox');
    final habitsBox = Hive.box('habits');
    final habitLogsBox = Hive.box('habitLogs');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1976D2),
      ),
      body: ValueListenableBuilder(
        valueListenable: inboxBox.listenable(),
        builder: (context, _, _) {
          return ValueListenableBuilder(
            valueListenable: habitsBox.listenable(),
            builder: (context, _, _) {
              return ValueListenableBuilder(
                valueListenable: habitLogsBox.listenable(),
                builder: (context, _, _) {
                  final now = DateTime.now();
                  final weekDays = weekDaysMonSun(now); // 7 days

                  // ==== Load inbox items ====
                  final inboxItems = inboxBox.values
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList();

                  // ✅ treat missing type as task (older data)
                  bool isTask(Map<String, dynamic> it) {
                    final t = it['type'];
                    return t == null || t == InboxType.task;
                  }

                  // Tasks completed THIS WEEK
                  int tasksCompletedWeek = 0;
                  for (final it in inboxItems) {
                    if (!isTask(it)) continue;
                    if ((it['isDone'] ?? false) != true) continue;

                    final createdAt = DateTime.tryParse(it['createdAt'] ?? '');
                    if (createdAt == null) continue;

                    // if within this week range
                    final start = weekDays.first;
                    final end = weekDays.last.add(const Duration(days: 1));
                    if (createdAt.isAfter(start.subtract(const Duration(seconds: 1))) &&
                        createdAt.isBefore(end)) {
                      tasksCompletedWeek += 1;
                    }
                  }

                  // ==== Load habits ====
                  final habits = habitsBox.values
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList();

                  // Best streak among habits
                  int bestStreak = 0;
                  for (final h in habits) {
                    final id = h['id'] as String;
                    final s = _streakCount(habitLogsBox, id);
                    if (s > bestStreak) bestStreak = s;
                  }

                  // Active days this week (days with at least 1 habit done)
                  int activeDays = 0;
                  for (final d in weekDays) {
                    final k = dateKey(d);
                    bool anyDone = false;

                    for (final h in habits) {
                      final id = h['id'] as String;
                      final log = habitLogsBox.get("${id}_$k");
                      if (log == null) continue;
                      final m = Map<String, dynamic>.from(log);
                      if ((m['done'] ?? false) == true) {
                        anyDone = true;
                        break;
                      }
                    }

                    if (anyDone) activeDays += 1;
                  }

                  // Weekly bars:
                  // We'll count (habits done + tasks done) per day.
                  final bars = <double>[];
                  for (final d in weekDays) {
                    final dayKey = dateKey(d);

                    // habits done that day
                    int habitsDone = 0;
                    for (final h in habits) {
                      final id = h['id'] as String;
                      final log = habitLogsBox.get("${id}_$dayKey");
                      if (log == null) continue;
                      final m = Map<String, dynamic>.from(log);
                      if ((m['done'] ?? false) == true) habitsDone += 1;
                    }

                    // tasks done that day (approx by createdAt day)
                    int tasksDone = 0;
                    for (final it in inboxItems) {
                      if (!isTask(it)) continue;
                      if ((it['isDone'] ?? false) != true) continue;
                      final createdAt = DateTime.tryParse(it['createdAt'] ?? '');
                      if (createdAt == null) continue;
                      if (dateKey(createdAt) == dayKey) tasksDone += 1;
                    }

                    bars.add((habitsDone + tasksDone).toDouble());
                  }

                  final weekLabel =
                      "${DateFormat('MMM d').format(weekDays.first)} - ${DateFormat('MMM d').format(weekDays.last)}";

                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: ListView(
                      children: [
                        Text(
                          'This Week',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          weekLabel,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                title: 'Tasks Completed',
                                value: tasksCompletedWeek.toString(),
                                icon: Icons.check_circle_outline,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                title: 'Best Streak',
                                value: '$bestStreak',
                                icon: Icons.local_fire_department_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        _StatCard(
                          title: 'Active Days',
                          value: '$activeDays / 7',
                          icon: Icons.calendar_today_outlined,
                        ),

                        const SizedBox(height: 16),

                        _ChartCard(
                          title: 'Weekly Progress',
                          child: SizedBox(
                            height: 220,
                            child: BarChart(
                              BarChartData(
                                gridData: const FlGridData(show: true),
                                borderData: FlBorderData(show: false),
                                titlesData: FlTitlesData(
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  leftTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: true, reservedSize: 28),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        final i = value.toInt();
                                        if (i < 0 || i > 6) return const SizedBox.shrink();
                                        final label = DateFormat('E').format(weekDays[i]); // Mon, Tue
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Text(label, style: const TextStyle(fontSize: 11)),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                barGroups: List.generate(7, (i) {
                                  return BarChartGroupData(
                                    x: i,
                                    barRods: [
                                      BarChartRodData(
                                        toY: bars[i],
                                        width: 14,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ],
                                  );
                                }),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  int _streakCount(Box habitLogsBox, String habitId) {
    // consecutive days DONE ending today if done today else ending yesterday
    final now = DateTime.now();

    bool doneOn(DateTime d) {
      final k = "${habitId}_${dateKey(d)}";
      final log = habitLogsBox.get(k);
      if (log == null) return false;
      final m = Map<String, dynamic>.from(log);
      return (m['done'] ?? false) == true;
    }

    final todayDone = doneOn(now);
    DateTime cursor = todayDone ? now : now.subtract(const Duration(days: 1));

    int streak = 0;
    while (true) {
      if (!doneOn(cursor)) break;
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 2),
            color: Colors.black.withValues(alpha: 0.05),
          )
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1976D2)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 2),
            color: Colors.black.withValues(alpha: 0.05),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
