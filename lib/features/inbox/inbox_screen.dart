import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/utils/inbox_types.dart';
import 'add_item_sheet.dart';
import 'package:go_router/go_router.dart';


class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inboxBox = Hive.box('inbox');

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Inbox', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1976D2),
        actions: [
          IconButton(
            icon: const Icon(Icons.today, color: Colors.white),
            onPressed: () => context.go('/today'),
          ),
          IconButton(
            icon: const Icon(Icons.checklist, color: Colors.white),
            onPressed: () => context.go('/habits'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Top input look (like screenshot) — opens bottom sheet
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openAddSheet(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Add a note or goal...',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                    const Icon(Icons.more_horiz, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: ValueListenableBuilder(
                valueListenable: inboxBox.listenable(),
                builder: (context, box, _) {
                  if (box.isEmpty) {
                    return const Center(
                      child: Text(
                        'No items yet.\nTap “+ Add Item” to add your first one.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final items = box.values
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList();

                  // Sort by newest first
                  items.sort((a, b) {
                    final da = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime(0);
                    final db = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime(0);
                    return db.compareTo(da);
                  });

                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _InboxTile(item: item);
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            // Bottom "+ Add Item" button like screenshot
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => _openAddSheet(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => const AddItemSheet(),
    );
  }
}

class _InboxTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _InboxTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final inboxBox = Hive.box('inbox');
    final id = item['id'] as String;
    final title = (item['title'] ?? '').toString();
    final type = (item['type'] ?? InboxType.task).toString();
    final isDone = (item['isDone'] ?? false) as bool;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          // For MVP: only tasks can be checked; later add for all types if you want
          Checkbox(
            value: isDone,
            onChanged: (v) async {
              await inboxBox.put(id, {...item, 'isDone': v ?? false});
            },
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                decoration: isDone ? TextDecoration.lineThrough : null,
                color: isDone ? Colors.grey : Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _TagPill(type: type),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => inboxBox.delete(id),
            icon: const Icon(Icons.delete_outline),
            color: Colors.grey.shade700,
          ),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  final String type;
  const _TagPill({required this.type});

  @override
  Widget build(BuildContext context) {
    final (bg, text) = _colors(type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _label(type),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
    );
  }

  (Color, Color) _colors(String t) {
    switch (t) {
      case InboxType.task:
        return (const Color(0xFFFFF3CD), const Color(0xFF8A6D3B)); // yellow
      case InboxType.goal:
        return (const Color(0xFFDCEBFF), const Color(0xFF1E5AA8)); // blue
      case InboxType.habit:
        return (const Color(0xFFDFF5E1), const Color(0xFF1E7A34)); // green
      case InboxType.reminder:
        return (const Color(0xFFFFD6D6), const Color(0xFFB00020)); // red
      default:
        return (Colors.grey.shade200, Colors.black);
    }
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
