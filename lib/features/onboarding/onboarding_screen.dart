import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  double focusMinutes = 60;

  final Map<String, bool> selected = {
    'Read 20 mins': true,
    'Exercise Daily': true,
    'Sleep by 11 PM': true,
  };

  final Map<String, String> iconKey = {
    'Read 20 mins': 'book',
    'Exercise Daily': 'run',
    'Sleep by 11 PM': 'moon',
  };

  Future<void> _continue() async {
    final settings = Hive.box('settings');
    final habitsBox = Hive.box('habits');
    final uuid = const Uuid();

    // Save settings
    await settings.put('focusMinutes', focusMinutes.round());
    await settings.put('onboardingDone', true);

    // Create selected starter habits (only once)
    if (habitsBox.isEmpty) {
      for (final entry in selected.entries) {
        if (!entry.value) continue;

        final id = uuid.v4();
        await habitsBox.put(id, {
          'id': id,
          'name': entry.key,
          'iconKey': iconKey[entry.key] ?? 'check',
          'createdAt': DateTime.now().toIso8601String(),
          'schedule': 'daily',
        });
      }
    }

    if (!mounted) return;
    context.go('/inbox');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Onboarding', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1976D2),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              'How much focus time\ncan you give daily?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Slider(
              min: 15,
              max: 240,
              divisions: 15,
              value: focusMinutes,
              onChanged: (v) => setState(() => focusMinutes = v),
            ),
            Text(
              '${focusMinutes.round()} minutes/day',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 18),
            const Text(
              'Set Your Habits:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),

            _HabitPickTile(
              title: 'Read 20 mins',
              emoji: '📚',
              selected: selected['Read 20 mins'] ?? false,
              onTap: () => setState(() {
                selected['Read 20 mins'] = !(selected['Read 20 mins'] ?? false);
              }),
            ),
            const SizedBox(height: 10),
            _HabitPickTile(
              title: 'Exercise Daily',
              emoji: '🏃',
              selected: selected['Exercise Daily'] ?? false,
              onTap: () => setState(() {
                selected['Exercise Daily'] = !(selected['Exercise Daily'] ?? false);
              }),
            ),
            const SizedBox(height: 10),
            _HabitPickTile(
              title: 'Sleep by 11 PM',
              emoji: '🌙',
              selected: selected['Sleep by 11 PM'] ?? false,
              onTap: () => setState(() {
                selected['Sleep by 11 PM'] = !(selected['Sleep by 11 PM'] ?? false);
              }),
            ),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _continue,
                child: const Text(
                  'Continue',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitPickTile extends StatelessWidget {
  final String title;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  const _HabitPickTile({
    required this.title,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              blurRadius: 8,
              offset: const Offset(0, 2),
              color: Colors.black.withValues(alpha: 0.05),
            )
          ],
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 16)),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? const Color(0xFF2E7D32) : Colors.grey,
            )
          ],
        ),
      ),
    );
  }
}
