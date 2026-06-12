import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/utils/date_keys.dart';
import '../../core/services/alarm_service.dart';

class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final habitsBox = Hive.box('habits');
    final habitLogsBox = Hive.box('habitLogs');

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Habits', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1976D2),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => context.go('/addHabit'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder(
          valueListenable: habitsBox.listenable(),
          builder: (context, habitsBoxValue, _) {
            return ValueListenableBuilder(
              valueListenable: habitLogsBox.listenable(),
              builder: (context, habitLogsValue, _) {
                final habits = habitsBox.values
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList();

                if (habits.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'No habits yet.',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => context.go('/addHabit'),
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text(
                            'Add Habit',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Sort by creation timeline
                habits.sort((a, b) {
                  final da = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime(0);
                  final db = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime(0);
                  return da.compareTo(db);
                });

                return ListView.separated(
                  itemCount: habits.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final h = habits[index];
                    final id = h['id'] as String;
                    final name = (h['name'] ?? '').toString();
                    final iconKey = (h['iconKey'] ?? 'check').toString();

                    final doneToday = _isDoneToday(habitLogsBox, id);
                    final streak = _streakCount(habitLogsBox, id);

                    return _HabitCard(
                      name: name,
                      iconKey: iconKey,
                      doneToday: doneToday,
                      streak: streak,
                      fire: streak, 
                      onToggleDoneToday: () async {
                        await _toggleDoneToday(habitLogsBox, id, !doneToday);
                      },
                      onDelete: () async {
                        // Cancel background system reminders before removing them from local database memory
                        final alarmId = h['alarmId'] as int?;
                        if (alarmId != null) {
                          await AlarmService.cancelAlarm(alarmId);
                        }
                        await habitsBox.delete(id);
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1976D2),
        onPressed: () => context.go('/addHabit'),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Habit', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // ===== Business Logic Methods =====

  bool _isDoneToday(Box habitLogsBox, String habitId) {
    final todayKey = dateKey(DateTime.now());
    final key = "${habitId}_$todayKey";
    final log = habitLogsBox.get(key);
    if (log == null) return false;
    final m = Map<String, dynamic>.from(log);
    return (m['done'] ?? false) as bool;
  }

  Future<void> _toggleDoneToday(Box habitLogsBox, String habitId, bool done) async {
    final todayKey = dateKey(DateTime.now());
    final key = "${habitId}_$todayKey";
    await habitLogsBox.put(key, {
      'habitId': habitId,
      'dateKey': todayKey,
      'done': done,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  int _streakCount(Box habitLogsBox, String habitId) {
    final now = DateTime.now();
    final todayDone = _isDoneToday(habitLogsBox, habitId);

    DateTime cursor = todayDone ? now : now.subtract(const Duration(days: 1));

    int streak = 0;
    while (true) {
      final k = "${habitId}_${dateKey(cursor)}";
      final log = habitLogsBox.get(k);
      if (log == null) break;

      final m = Map<String, dynamic>.from(log);
      final done = (m['done'] ?? false) as bool;
      if (!done) break;

      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}

// ===== Structural Component Card =====

class _HabitCard extends StatelessWidget {
  final String name;
  final String iconKey;
  final bool doneToday;
  final int streak;
  final int fire;
  final VoidCallback onToggleDoneToday;
  final VoidCallback onDelete;

  const _HabitCard({
    required this.name,
    required this.iconKey,
    required this.doneToday,
    required this.streak,
    required this.fire,
    required this.onToggleDoneToday,
    required this.onDelete,
  });

  String _emoji(String key) {
    switch (key) {
      case 'book': return '📚';
      case 'run': return '🏃';
      case 'moon': return '🌙';
      case 'water': return '💧';
      case 'study': return '🧠';
      case 'gym': return '🏋️';
      default: return '✅';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onToggleDoneToday,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              offset: const Offset(0, 2),
              color: Colors.black.withOpacity(0.05), // Fixed for backward compatibility support
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(_emoji(iconKey), style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Streak: $streak Days',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '🔥 $fire',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              doneToday ? Icons.check_circle : Icons.radio_button_unchecked,
              color: doneToday ? const Color(0xFF2E7D32) : Colors.grey,
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              color: Colors.grey.shade700,
            ),
          ],
        ),
      ),
    );
  }
}