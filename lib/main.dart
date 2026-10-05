import 'dart:async';

import 'package:ai_remote/core/app_controller.dart';
import 'package:ai_remote/core/app_factory.dart';
import 'package:ai_remote/ui/home_screen.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = await createDefaultAppController();
  await controller.initialize();
  runApp(AiRemoteApp(controller: controller));
}

class AiRemoteApp extends StatefulWidget {
  const AiRemoteApp({super.key, required this.controller});

  final AppController controller;

  @override
  State<AiRemoteApp> createState() => _AiRemoteAppState();
}

class _AiRemoteAppState extends State<AiRemoteApp> {
  @override
  void dispose() {
    unawaited(widget.controller.shutdown());
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Remote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF63E6BE),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF07101D),
      ),
      home: HomeScreen(controller: widget.controller),
    );
  }
}
