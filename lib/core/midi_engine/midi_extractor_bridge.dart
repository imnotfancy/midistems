import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

/// Bridge for communicating with Python MIDI extractor
class MidiExtractorBridge {
  static final _logger = Logger('MidiExtractorBridge');

  String get _pythonScript {
    // During tests, use the current working directory
    final workingDir = Directory.current.path;
    return path.join(workingDir, 'python', 'midi_extractor.py');
  }
  Process? _process;
  bool _isInitialized = false;

  /// Initialize the MIDI extractor
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check Python environment
      _logger.info('Checking Python environment...');
      final result = await Process.run('python', ['--version']);
      _logger.fine('Python version check result: ${result.stdout}');
      if (result.exitCode != 0) {
        _logger.severe('Python version check failed: ${result.stderr}');
        throw Exception('Python not found');
      }

      // Verify capabilities
      _logger.info('Verifying MIDI extractor capabilities...');
      _logger.fine('Script path: $_pythonScript');
      final process = await Process.start('python', [
        _pythonScript,
        'check_capabilities',
      ]);

      // Capture output for debugging and JSON parsing
      final stdoutBuffer = StringBuffer();
      process.stdout.transform(utf8.decoder).listen(stdoutBuffer.write);

      final stderrBuffer = StringBuffer();
      process.stderr.transform(utf8.decoder).listen(stderrBuffer.write);

      final exitCode = await process.exitCode;
      final stdoutString = stdoutBuffer.toString().trim();
      final stderrString = stderrBuffer.toString().trim();

      if (stderrString.isNotEmpty) {
        _logger.warning('MIDI extractor stderr (capabilities): $stderrString');
      }

      if (stdoutString.isNotEmpty) {
        _logger.fine('MIDI extractor stdout (capabilities): $stdoutString');
        try {
          final jsonResponse = json.decode(stdoutString) as Map<String, dynamic>;
          if (jsonResponse['status'] == 'success') {
            _logger.info('MIDI extractor capability check successful: ${jsonResponse['message']}');
            _isInitialized = true;
          } else if (jsonResponse['status'] == 'error') {
            _logger.severe('MIDI extractor capability check failed: ${jsonResponse['error']}');
            throw Exception('Failed to initialize MIDI extractor: ${jsonResponse['error']}');
          } else {
            // Fallback if JSON status is unknown but exit code might be 0
            if (exitCode == 0) {
               _logger.warning('MIDI extractor capability check returned unknown JSON status with exit code 0. Output: $stdoutString');
               // Potentially treat as success or require specific handling. For now, let's be strict.
               throw Exception('Failed to initialize MIDI extractor: Unknown JSON status from script.');
            } else {
               _logger.severe('MIDI extractor capability check failed with exit code $exitCode and unknown JSON status. Output: $stdoutString');
               throw Exception('Failed to initialize MIDI extractor (exit code $exitCode, unknown JSON status)');
            }
          }
        } catch (e) {
          _logger.severe('Failed to parse JSON from MIDI extractor capability check or unexpected error: $e. Raw output: $stdoutString');
          // Fallback to exit code if JSON parsing fails
          if (exitCode != 0) {
            throw Exception('Failed to initialize MIDI extractor (exit code $exitCode, JSON parsing failed)');
          } else {
            // If exit code was 0 but stdout wasn't the expected JSON, it's still an issue.
             throw Exception('Failed to initialize MIDI extractor (JSON parsing failed, unexpected output: $stdoutString)');
          }
        }
      } else {
        // No stdout, rely on exit code
        if (exitCode != 0) {
          _logger.severe('MIDI extractor capability check failed with exit code $exitCode and no stdout.');
          throw Exception('Failed to initialize MIDI extractor (exit code $exitCode, no output)');
        } else {
          // This case (exit code 0, no stdout) should ideally not happen with the new python script.
          _logger.warning('MIDI extractor capability check returned exit code 0 but no stdout. This is unexpected.');
          throw Exception('Failed to initialize MIDI extractor (exit code 0, no output, unexpected state)');
        }
      }
      // If we reach here and _isInitialized is true, it means success.
      if (!_isInitialized) {
         // This should ideally be caught by one of the specific error conditions above.
         _logger.severe('MIDI extractor initialization failed due to an unknown reason after checks.');
         throw Exception('Failed to initialize MIDI extractor (unknown reason)');
      }

    } catch (e) {
      _logger.severe('Failed to initialize MIDI extractor: $e');
      // Ensure the original exception is re-thrown if it's not one of our specific new ones.
      // The new exceptions are already specific.
      if (e is Exception && e.toString().startsWith('Exception: Failed to initialize MIDI extractor')) {
        rethrow;
      }
      throw Exception('Failed to initialize MIDI extractor: $e');
    }
  }

  /// Extract MIDI data from audio file
  Future<Map<String, dynamic>> extractMidi(
    String inputPath,
    String outputPath, {
    void Function(String)? onProgress,
    Map<String, dynamic>? settings,
  }) async {
    if (!_isInitialized) {
      _logger.severe('MIDI extractor not initialized');
      throw Exception('MIDI extractor not initialized');
    }

    try {
      // Start Python process
      final args = [
        _pythonScript,
        'extract_midi',
        'input_path=$inputPath',
        'output_path=$outputPath',
      ];

      if (settings != null) {
        for (final entry in settings.entries) {
          args.add('${entry.key}=${entry.value}');
        }
      }

      _process = await Process.start('python', args);

      // Listen for progress updates
      _process!.stderr.transform(utf8.decoder).listen((data) {
        if (data.startsWith('INFO: ')) {
          final message = data.substring(6).trim();
          _logger.info(message);
          onProgress?.call(message);
        }
      });

      // Get result
      final output = await _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .where((line) => line.isNotEmpty)
          .last;

      final result = json.decode(output) as Map<String, dynamic>;

      if (result['status'] == 'success') {
        if (result.containsKey('result')) {
          // New structure: actual data is nested under 'result'
          return result['result'] as Map<String, dynamic>;
        } else {
          // Should not happen if Python script adheres to new contract
          _logger.severe('MIDI extraction status is success, but "result" key is missing.');
          throw Exception('MIDI extraction failed: Invalid success response format.');
        }
      } else if (result['status'] == 'error') {
        final errorMessage = result['error']?.toString() ?? 'Unknown error from MIDI extractor.';
        _logger.severe('MIDI extraction failed: $errorMessage');
        throw Exception(errorMessage);
      } else {
        // Unknown status
        _logger.severe('MIDI extraction returned unknown status: ${result['status']}');
        throw Exception('MIDI extraction failed: Unknown status from script.');
      }
    } catch (e) {
      _logger.severe('Failed to extract MIDI: $e');
      throw Exception('Failed to extract MIDI: $e');
    } finally {
      _process?.kill();
      _process = null;
    }
  }

  /// Clean up resources
  void dispose() {
    _process?.kill();
    _process = null;
    _isInitialized = false;
  }
}