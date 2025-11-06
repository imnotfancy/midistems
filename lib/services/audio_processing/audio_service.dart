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

    final stdoutStr = result.stdout.toString().trim();
    Map<String, dynamic>? parsedJson;
    Exception? jsonParsingException;

    if (stdoutStr.isNotEmpty) {
      try {
        parsedJson = json.decode(stdoutStr) as Map<String, dynamic>;
      } on FormatException catch (e) {
        debugPrint('Failed to parse stdout JSON: $e');
        jsonParsingException = Exception('Failed to parse JSON response from Python script: $e. Raw output: "$stdoutStr"');
      }
    }

    // Prioritize JSON content if successfully parsed
    if (parsedJson != null) {
      final status = parsedJson['status'];
      if (status == 'success') {
        if (parsedJson.containsKey('result')) {
          return parsedJson['result'] as Map<String, dynamic>;
        } else {
          // Script contract violation: status success but no result field
          throw Exception('Python script reported success but "result" field is missing.');
        }
      } else if (status == 'error') {
        // Python script reported an application-level error via JSON
        final errorPayload = parsedJson['error'];
        throw Exception(errorPayload?.toString() ?? 'Unknown error from Python script (JSON error status)');
      } else {
        // Script contract violation: unknown status
        throw Exception('Unknown JSON status from Python script: "$status". Raw output: "$stdoutStr"');
      }
    }

    // Handle cases where JSON was not parsed or stdout was empty, now considering exit code
    if (result.exitCode != 0) {
      // Script failed and didn't produce a valid JSON error message that was handled above
      final stderrStr = result.stderr.toString().trim();
      if (jsonParsingException != null) {
        // Include JSON parsing error details if they exist, plus script error info
         throw Exception('Python script failed (exit code ${result.exitCode}) and produced malformed JSON. Stderr: "$stderrStr". JSON Error: ${jsonParsingException.toString()}');
      }
      throw Exception('Python script failed with exit code ${result.exitCode}: "$stderrStr"');
    }

    // If exitCode is 0, but we couldn't get a success/error status from JSON
    // (e.g. empty stdout, or stdout was not JSON, or JSON had no status)
    if (jsonParsingException != null) {
      throw jsonParsingException; // Throw the captured JSON parsing exception
    }
    if (stdoutStr.isEmpty) {
      throw Exception('Python script exited successfully but produced no output.');
    }
    // If stdout was not empty, but not valid JSON, and jsonParsingException was not thrown for some reason (should not happen)
    // Or if it was JSON but without a status field (already handled if parsedJson was not null)
    throw Exception('Python script exited successfully but produced unrecognized output: "$stdoutStr"');
  }
}