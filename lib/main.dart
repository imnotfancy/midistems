import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import 'package:audio_session/audio_session.dart';
import 'package:logging/logging.dart';
import 'ui/app.dart';
import 'rust_service.dart'; // Import the Rust service

Future<void> main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Configure logging
  Logger.root.level = kDebugMode ? Level.ALL : Level.INFO;
  Logger.root.onRecord.listen((record) {
    if (kDebugMode) {
      print('${record.level.name}: ${record.time}: ${record.message}');
      if (record.error != null) print(record.error);
      if (record.stackTrace != null) print(record.stackTrace);
    }
  });

  final logger = Logger('main');
  
  // Initialize audio session
  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    logger.info('Audio session configured successfully');
  } catch (e) {
    logger.severe('Failed to configure audio session', e);
  }
  
  // Initialize window settings for desktop
  await windowManager.ensureInitialized();
  await windowManager.setTitle('MidiStems');
  await windowManager.setMinimumSize(const Size(800, 600));
  await windowManager.setSize(const Size(1200, 800));

  runApp(const MidiStemsApp());

  // Run the Rust FFI example
  // Adding a try-catch in case of issues during FFI loading/calling for robustness
  try {
    logger.info("Attempting to run Rust FFI example...");
    await RustService.runExample();
    logger.info("Rust FFI example completed.");
  } catch (e, s) {
    logger.severe("Error running Rust FFI example:", e, s);
  }
}
