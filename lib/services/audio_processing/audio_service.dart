import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

class AudioService {
  /// This method checks if Python is installed and accessible, and if pip is available.
  Future<void> _verifyPythonSetup() async {
    try {
      // Check Python version
      final versionResult = await Process.run(pythonPath, ['--version']);
      if (versionResult.exitCode != 0) {
        throw Exception('Python not found at $pythonPath');
      }

      // Check pip availability
      final pipResult = await Process.run(pythonPath, ['-m', 'pip', '--version']);
      if (pipResult.exitCode != 0) {
        throw Exception('pip not installed');
      }
    } on ProcessException catch (e) {
      throw Exception('Python setup verification failed: ${e.message}');
    }
  }

  /// Dynamically determine the Python command path for Windows vs. other OS.
  /// Adjust if you keep Python in a different location or virtual env.
  String get pythonPath {
    if (Platform.isWindows) {
      // Example: a local venv under your project
      return path.join(Directory.current.path, 'venv', 'Scripts', 'python.exe');
    } else {
      return path.join(Directory.current.path, 'venv', 'bin', 'python');
    }
  }

  /// Calls a Python script (processor.py) to separate stems from [inputPath],
  /// placing results in [outputDir]. Returns a JSON result map.
  Future<Map<String, dynamic>> separateStems({
    required String inputPath,
    required String outputDir,
  }) async {
    await _verifyPythonSetup();

    debugPrint('Input file: $inputPath');
    debugPrint('Output directory: $outputDir');

    // Prepare command arguments
    final args = [
      path.join(Directory.current.path, 'python', 'processor.py'),
      'separate_stems',
      'input_path="$inputPath"',
      'output_dir="$outputDir"',
    ];

    debugPrint('\n=== Audio Processing Debug Info ===');
    debugPrint('Command: ${[pythonPath, ...args].join(' ')}');
    debugPrint('Working directory: ${Directory.current.path}');

    // Run the Python script
    final result = await Process.run(pythonPath, args);

    debugPrint('\nPython stderr output:\n${result.stderr}');
    debugPrint('\nPython stdout output:\n${result.stdout}');
    debugPrint('\nExit code: ${result.exitCode}');
    debugPrint('================================\n');

    // If script signaled an error
    if (result.exitCode != 0) {
      throw Exception(result.stderr.toString());
    }

    // Parse JSON output
    final jsonStr = result.stdout.toString().trim();
    final jsonResult = json.decode(jsonStr);

    if (jsonResult['status'] != 'success') {
      throw Exception(jsonResult['error'] ?? 'Unknown error during stem separation');
    }

    return jsonResult['result'] as Map<String, dynamic>;
  }
}