import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  static const int focusMinutes = 25; // Pomodoro focus
  static const int breakMinutes = 5;

  late int remainingSeconds;
  bool running = false;
  bool onBreak = false;

  Timer? timer;

  @override
  void initState() {
    super.initState();
    remainingSeconds = focusMinutes * 60;
  }

  void start() {
    if (running) return;

    setState(() => running = true);

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remainingSeconds <= 0) {
        _sessionFinished();
      } else {
        setState(() => remainingSeconds--);
      }
    });
  }

  void pause() {
    timer?.cancel();
    setState(() => running = false);
  }

  void reset() {
    timer?.cancel();
    setState(() {
      running = false;
      onBreak = false;
      remainingSeconds = focusMinutes * 60;
    });
  }

  Future<void> _sessionFinished() async {
    timer?.cancel();

    if (!onBreak) {
      // Save completed focus session
      final focusBox = Hive.box('focusSessions');
      await focusBox.add({
        'completedAt': DateTime.now().toIso8601String(),
        'minutes': focusMinutes,
      });
    }

    setState(() {
      onBreak = !onBreak;
      running = false;
      remainingSeconds =
          (onBreak ? breakMinutes : focusMinutes) * 60;
    });
  }

  String _time() {
    final m = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (remainingSeconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = onBreak ? "Break Time" : "Focus Time";

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1976D2),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              onBreak ? "Relax 🌿" : "Stay Focused 💪",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 30),

            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE3F2FD),
                border: Border.all(color: const Color(0xFF1976D2), width: 2),
              ),
              child: Text(
                _time(),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),

            const SizedBox(height: 40),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: running ? pause : start,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  child: Text(
                    running ? "Pause" : "Start",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),

                const SizedBox(width: 14),

                OutlinedButton(
                  onPressed: reset,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  child: const Text("Reset"),
                ),
              ],
            ),

            const SizedBox(height: 30),

            Text(
              onBreak
                  ? "Break: $breakMinutes minutes"
                  : "Focus: $focusMinutes minutes",
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}
