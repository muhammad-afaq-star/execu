import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/utils/date_keys.dart';
import '../../core/utils/inbox_types.dart';


class TodayPlanScreen extends StatelessWidget {
  const TodayPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inboxBox = Hive.box('inbox');
    final habitsBox = Hive.box('habits');
    final habitLogsBox = Hive.box('habitLogs');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Plan", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1976D2),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Go to Inbox',
            icon: const Icon(Icons.inbox, color: Colors.white),
            onPressed: () => context.go('/inbox'),
          ),
        ],
      ),

      body: ValueListenableBuilder(
        valueListenable: inboxBox.listenable(),
        builder: (context, inboxBoxValue, _) {
          return ValueListenableBuilder(
            valueListenable: habitsBox.listenable(),
            builder: (context, habitsBoxValue, _) {
              return ValueListenableBuilder(
                valueListenable: habitLogsBox.listenable(),
                builder: (context, habitLogsBoxValue, _) {
                  final today = DateTime.now();
                  final todayKey = dateKey(today);

                  // ===== Tasks (from inbox) =====
                  final allInbox = inboxBox.values
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList();

                  // ✅ treat missing type as task
                  final tasks = allInbox.where((it) {
                    final t = it['type'];
                    return t == null || t == InboxType.task;
                  }).toList();

                  // Sort: unfinished first
                  tasks.sort((a, b) {
                    final ad = (a['isDone'] ?? false) == true ? 1 : 0;
                    final bd = (b['isDone'] ?? false) == true ? 1 : 0;
                    return ad.compareTo(bd);
                  });

                  // Top task: first incomplete, else first
                  Map<String, dynamic>? topTask;
                  for (final t in tasks) {
                    if ((t['isDone'] ?? false) == false) {
                      topTask = t;
                      break;
                    }
                  }
                  topTask ??= tasks.isNotEmpty ? tasks.first : null;

                  // ===== Habits =====
                  final habits = habitsBox.values
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList();

                  bool isHabitDoneToday(String habitId) {
                    final key = "${habitId}_$todayKey";
                    final log = habitLogsBox.get(key);
                    if (log == null) return false;
                    final m = Map<String, dynamic>.from(log);
                    return (m['done'] ?? false) as bool;
                  }

                  Future<void> toggleHabit(String habitId, bool done) async {
                    final key = "${habitId}_$todayKey";
                    await habitLogsBox.put(key, {
                      'habitId': habitId,
                      'dateKey': todayKey,
                      'done': done,
                      'updatedAt': DateTime.now().toIso8601String(),
                    });
                  }

                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: ListView(
                      children: [
                        Text(
                          DateFormat('EEEE, MMMM d').format(today),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Top Task (priority)
                        _SectionCard(
                          title: 'Top Task',
                          trailing: const Icon(Icons.edit, size: 18),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3F2FD),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF1976D2),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1976D2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    topTask == null
                                        ? 'No tasks yet'
                                        : (topTask['title'] ?? ''),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0D47A1),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Tasks for Today (all tasks for MVP)
                        _SectionCard(
                          title: 'Tasks for Today',
                          child: tasks.isEmpty
                              ? const Text('No tasks yet. Add tasks in Inbox.')
                              : Column(
                            children: tasks.map((t) {
                              final id = t['id'] as String;
                              final title = (t['title'] ?? '').toString();
                              final done = (t['isDone'] ?? false) as bool;

                              return _CheckRow(
                                title: title,
                                value: done,
                                onChanged: (v) async {
                                  await inboxBox.put(
                                    id,
                                    {...t, 'isDone': v ?? false},
                                  );
                                },
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Daily Habits
                        _SectionCard(
                          title: 'Daily Habits',
                          child: habits.isEmpty
                              ? const Text('No habits yet.')
                              : Column(
                            children: habits.map((h) {
                              final id = h['id'] as String;
                              final name = (h['name'] ?? '').toString();
                              final done = isHabitDoneToday(id);

                              return _CheckRow(
                                title: name,
                                value: done,
                                onChanged: (v) async {
                                  await toggleHabit(id, v ?? false);
                                },
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Focus placeholder
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1976D2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Focus Session'),
                                  content: const Text(
                                    'MVP placeholder.\nNext step we will add a real timer screen.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        context.go('/focus');
                                      },
                                      child: const Text('OK'),
                                    )
                                  ],
                                ),
                              );
                            },
                            child: const Text(
                              'Start Focus Session',
                              style: TextStyle(color: Colors.white, fontSize: 16),
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
}

// ===== UI helpers =====

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _CheckRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(value: value, onChanged: onChanged),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              decoration: value ? TextDecoration.lineThrough : null,
              color: value ? Colors.grey : Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}
