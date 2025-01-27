import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

class MidiStemsApp extends StatelessWidget {
  const MidiStemsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MidiStems',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}