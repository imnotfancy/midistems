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

      // Capture output for debugging
      process.stdout.transform(utf8.decoder).listen((data) {
        _logger.fine('MIDI extractor stdout: $data');
      });
      process.stderr.transform(utf8.decoder).listen((data) {
        _logger.warning('MIDI extractor stderr: $data');
      });

      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        _logger.severe('MIDI extractor capability check failed with exit code: $exitCode');
        throw Exception('Failed to initialize MIDI extractor');
      }
      _logger.info('MIDI extractor initialized successfully');

      _isInitialized = true;
    } catch (e) {
      _logger.severe('Failed to initialize MIDI extractor', e);
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

      if (result['status'] == 'error') {
        _logger.severe('MIDI extraction failed: ${result['error']}');
        throw Exception(result['error']);
      }

      return result;
    } catch (e) {
      _logger.severe('Failed to extract MIDI', e);
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