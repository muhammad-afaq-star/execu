import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openBox('habits');
  await Hive.openBox('habitLogs');
  await Hive.openBox('inbox');
  await Hive.openBox('focusSessions');

  runApp(const ExecuApp());
}

class ExecuApp extends StatelessWidget {
  const ExecuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
    );
  }
}
