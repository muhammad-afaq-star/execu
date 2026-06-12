import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/inbox_types.dart';

class AddItemSheet extends StatefulWidget {
  const AddItemSheet({super.key});

  @override
  State<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<AddItemSheet> {
  final controller = TextEditingController();
  String type = InboxType.task;

  Future<void> _save() async {
    final title = controller.text.trim();
    if (title.isEmpty) return;

    final inboxBox = Hive.box('inbox');
    final id = const Uuid().v4();

    await inboxBox.put(id, {
      'id': id,
      'title': title,
      'type': type,
      'createdAt': DateTime.now().toIso8601String(),
      'isDone': false,
      // For MVP: no due date. Later we can add it.
    });

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Add Item',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Add a note or goal...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 10,
            children: InboxType.all.map((t) {
              final selected = t == type;
              return ChoiceChip(
                selected: selected,
                label: Text(_label(t)),
                onSelected: (_) => setState(() => type = t),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _save,
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  String _label(String t) {
    switch (t) {
      case InboxType.task:
        return 'Task';
      case InboxType.goal:
        return 'Goal';
      case InboxType.habit:
        return 'Habit';
      case InboxType.reminder:
        return 'Reminder';
      default:
        return t;
    }
  }
}
