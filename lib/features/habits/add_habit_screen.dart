import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
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
    // 1. Check for precise Android hardware alarm permissions
    if (await Permission.scheduleExactAlarm.request().isDenied) {
      Fluttertoast.showToast(
        msg: "⚠️ Please enable Alarm permissions in settings!",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      // Direct the user to the system app settings to manually grant it
      await openAppSettings();
      return;
    }

    // 2. Check for Notification permissions (required for Android 13+ to actually see/hear the alarm)
    if (await Permission.notification.request().isDenied) {
      Fluttertoast.showToast(
        msg: "⚠️ Please enable Notification permissions in settings!",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      await openAppSettings();
      return;
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
    );
    
    if (picked != null) {
      onTimePicked(picked);

      final now = DateTime.now();
      var targetDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        picked.hour,
        picked.minute,
      );

      if (targetDateTime.isBefore(now)) {
        targetDateTime = targetDateTime.add(const Duration(days: 1));
      }

      // Calculate the explicit remaining time window
      final difference = targetDateTime.difference(now);
      final hours = difference.inHours;
      final minutes = difference.inMinutes % 60;

      String timeWindowStr = hours > 0 
          ? "in $hours hr $minutes mins" 
          : "in $minutes minutes";

      // Display the dynamic remaining-time success toast message
      Fluttertoast.showToast(
        msg: "⏰ Alarm Set: ${picked.format(context)} ($timeWindowStr)",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: const Color(0xFF1976D2),
        textColor: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        leading: const Icon(Icons.alarm, color: Color(0xFF1976D2)),
        title: Text(
          selectedTime == null
              ? 'Set Reminder Alarm'
              : 'Alarm Set For: ${selectedTime!.format(context)}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => _pickTime(context),
          child: const Text('Pick Time', style: TextStyle(color: Colors.white)),
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
  String? _selectedAudioPath;
  String? _selectedAudioName;
  bool _isTestingAlarm = false;

  final icons = const [
    ('book', '📚'),
    ('run', '🏃'),
    ('moon', '🌙'),
    ('water', '💧'),
    ('study', '🧠'),
    ('gym', '🏋️'),
    ('check', '✅'),
  ];

  // Open native system file picker to select an audio file from gallery/storage
  Future<void> _pickAudioTone() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );
    if (result != null && result.files.single.path != null) {
      final originalPath = result.files.single.path!;
      final fileName = result.files.single.name;

      // Copy the picked file to the app's permanent document directory
      final appDir = await getApplicationDocumentsDirectory();
      final permanentFile = await File(originalPath).copy('${appDir.path}/$fileName');

      setState(() {
        _selectedAudioPath = permanentFile.path;
        _selectedAudioName = fileName;
      });
    }
  }

  Future<void> _save() async {
    final name = controller.text.trim();
    if (name.isEmpty) return;

    final habitsBox = Hive.box('habits');
    final id = const Uuid().v4();
    // Ensure the generated ID fits safely into a 32-bit signed integer (Android's native limit)
    final uniqueAlarmId = id.hashCode.abs() % 2147483647; 

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

      if (targetDateTime.isBefore(now)) {
        targetDateTime = targetDateTime.add(const Duration(days: 1));
      }

      reminderIsoString = targetDateTime.toIso8601String();
      await AlarmService.setAlarm(uniqueAlarmId, targetDateTime, customTonePath: _selectedAudioPath);
    }

    // Save configuration parameters payload securely to local database
    await habitsBox.put(id, {
      'id': id,
      'alarmId': uniqueAlarmId,
      'name': name,
      'iconKey': iconKey,
      'createdAt': DateTime.now().toIso8601String(),
      'schedule': 'daily',
      'reminderTime': reminderIsoString,
      'customTonePath': _selectedAudioPath, 
    });

    if (!mounted) return;
    context.pop();
  }

  @override
  void dispose() {
    if (_isTestingAlarm) {
      AlarmService.cancelAlarm(8888);
    }
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
            const SizedBox(height: 20),

            const Text('Reminders', style: TextStyle(fontWeight: FontWeight.w700)),
            AlarmSettingWidget(
              selectedTime: _reminderTime,
              onTimePicked: (time) => setState(() => _reminderTime = time),
            ),
            const SizedBox(height: 12),

            const Text('Alarm Tone From Gallery', style: TextStyle(fontWeight: FontWeight.w700)),
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: ListTile(
                leading: const Icon(Icons.music_note, color: Color(0xFF1976D2)),
                title: Text(
                  _selectedAudioName ?? 'Default Ringtone',
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () async {
                        if (_isTestingAlarm) {
                          await AlarmService.cancelAlarm(8888);
                        } else {
                          await AlarmService.showInstantNotification(8888, audioPath: _selectedAudioPath);
                        }
                        setState(() => _isTestingAlarm = !_isTestingAlarm);
                      },
                      child: Text(_isTestingAlarm ? 'Stop' : 'Test'),
                    ),
                    TextButton(
                      onPressed: _pickAudioTone,
                      child: const Text('Browse'),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _save,
                child: const Text('Save Habit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}