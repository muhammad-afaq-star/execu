import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/alarm_service.dart';

class AlarmSettingWidget extends StatelessWidget {
  final TimeOfDay? selectedTime;
  final ValueChanged<TimeOfDay?> onTimePicked;

  const AlarmSettingWidget({
    super.key,
    required this.selectedTime,
    required this.onTimePicked,
  });

  Future<void> _pickTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
    );
    if (!context.mounted) return;
    if (picked != null) {
      onTimePicked(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: const Icon(Icons.alarm, color: Color(0xFF1976D2)),
        title: Text(
          selectedTime == null
              ? 'Set Reminder Alarm'
              : 'Alarm Set For: ${selectedTime!.format(context)}',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: selectedTime == null ? const Color(0xFF1976D2) : Colors.grey.shade200,
            foregroundColor: selectedTime == null ? Colors.white : Colors.black87,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => _pickTime(context),
          child: Text(selectedTime == null ? 'Pick Time' : 'Change'),
        ),
      ),
    );
  }
}

class AddHabitScreen extends StatefulWidget {
  const AddHabitScreen({super.key});

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  final controller = TextEditingController();
  String iconKey = 'check';
  TimeOfDay? _reminderTime;

  final icons = const [
    ('book', '📚'),
    ('run', '🏃'),
    ('moon', '🌙'),
    ('water', '💧'),
    ('study', '🧠'),
    ('gym', '🏋️'),
    ('check', '✅'),
  ];

  Future<void> _save() async {
    final name = controller.text.trim();
    if (name.isEmpty) return;

    final habitsBox = Hive.box('habits');
    final id = const Uuid().v4();
    
    // We generate a deterministic integer ID out of the UUID string hash code
    // to map this specific habit entity safely with the Android system Alarm Manager
    final uniqueAlarmId = id.hashCode.abs(); 

    String? reminderIsoString;

    if (_reminderTime != null) {
      final now = DateTime.now();
      var targetDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        _reminderTime!.hour,
        _reminderTime!.minute,
      );

      // If the selected time has already passed today, shift it safely to tomorrow
      if (targetDateTime.isBefore(now)) {
        targetDateTime = targetDateTime.add(const Duration(days: 1));
      }

      reminderIsoString = targetDateTime.toIso8601String();

      // Trigger your Alarm Service engine tracking hook
      await AlarmService.setAlarm(uniqueAlarmId, targetDateTime);
    }

    // Save payload structure to local Hive database
    await habitsBox.put(id, {
      'id': id,
      'alarmId': uniqueAlarmId,
      'name': name,
      'iconKey': iconKey,
      'createdAt': DateTime.now().toIso8601String(),
      'schedule': 'daily',
      'reminderTime': reminderIsoString, // Will store null if user did not pick an alarm
    });

    if (!mounted) return;
    
    if (_reminderTime != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$name" saved with alarm at ${_reminderTime!.format(context)}'),
          backgroundColor: const Color(0xFF1976D2),
        ),
      );
    }
    
    context.pop();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Habit', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1976D2),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Habit name', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'e.g., Read 10 pages',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            const Text('Choose icon', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: icons.map((pair) {
                final key = pair.$1;
                final emoji = pair.$2;
                final selected = iconKey == key;

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => iconKey = key),
                  child: Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFE3F2FD) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? const Color(0xFF1976D2) : Colors.grey.shade300,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            const Text('Reminders', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            AlarmSettingWidget(
              selectedTime: _reminderTime,
              onTimePicked: (time) {
                setState(() {
                  _reminderTime = time;
                });
              },
            ),

            const Spacer(),

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
                onPressed: _save,
                child: const Text('Save Habit', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}