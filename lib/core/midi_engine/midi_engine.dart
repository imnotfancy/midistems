import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'midi_extractor_bridge.dart';
import 'midi_writer.dart';
import 'models.dart';
import 'progress_reporter.dart';

/// Main MIDI engine class that handles MIDI extraction, playback, and file operations.
///
/// The engine provides functionality to:
/// - Extract MIDI data from audio files
/// - Basic playback control of MIDI tracks
/// - Export MIDI data to files
/// - Track progress and project state
///
/// Example usage:
/// ```dart
/// final engine = MidiEngine();
/// await engine.initialize();
///
/// // Extract MIDI from audio
/// final project = await engine.extractFromAudio('audio.wav');
///
/// // Play a specific track
/// await engine.playTrack(project.tracks.first.id);
///
/// // Stop playback
/// await engine.stopPlayback();
/// ```
class MidiEngine {
  final _extractorBridge = MidiExtractorBridge();
  final _progressReporter = ProgressReporter();
  final _projectController = StreamController<MidiProject>.broadcast();
  MidiProject? _currentProject;
  MidiExtractionSettings _extractionSettings = const MidiExtractionSettings();
  bool _isPlaying = false;

  /// Stream of project updates
  Stream<MidiProject> get projectUpdates => _projectController.stream;

  /// Stream of progress updates
  Stream<ProgressUpdate> get progress => _progressReporter.updates;

  /// Initialize the MIDI engine
  Future<void> initialize() async {
    try {
      await _extractorBridge.initialize();
    } catch (e) {
      throw Exception('Failed to initialize MIDI engine: $e');
    }
  }

  /// Extract MIDI data from an audio file.
  ///
  /// This method will:
  /// 1. Create an output directory for the MIDI file
  /// 2. Extract MIDI data using the configured settings
  /// 3. Create a project with the extracted data
  /// 4. Emit progress updates during the process
  ///
  /// Returns a [MidiProject] containing the extracted MIDI data.
  /// Throws an [Exception] if extraction fails.
  Future<MidiProject> extractFromAudio(String audioPath) async {
    _progressReporter.start();
    _progressReporter.report('Starting MIDI extraction...', 0.0);

    try {
      // Create output directory if it doesn't exist
      final outputDir = path.join(
        path.dirname(audioPath),
        'midi_output',
      );
      await Directory(outputDir).create(recursive: true);

      // Generate output path
      final outputPath = path.join(
        outputDir,
        '${path.basenameWithoutExtension(audioPath)}.mid',
      );

      // Convert settings to map
      final settingsMap = {
        'onset_threshold': _extractionSettings.onsetThreshold,
        'frame_threshold': _extractionSettings.frameThreshold,
        'min_note_length': _extractionSettings.minNoteLength,
        'min_frequency': _extractionSettings.minimumFrequency,
        'max_frequency': _extractionSettings.maximumFrequency,
        'multiple_pitch_bends': _extractionSettings.multiplePitchBends,
        'melodia_trick': _extractionSettings.melodiaTrick,
      };

      // Extract MIDI with settings
      final result = await _extractorBridge.extractMidi(
        audioPath,
        outputPath,
        onProgress: (message) {
          _progressReporter.report(message, 0.5);
        },
        settings: settingsMap,
      );

      // Create project from extraction result
      final project = MidiProject(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        tracks: [
          MidiTrack(
            id: 'track-1',
            name: path.basenameWithoutExtension(audioPath),
            notes: _parseNotes(result['result']['details']['notes']),
            channel: 0,
          ),
        ],
        metadata: MidiMetadata(
          title: path.basenameWithoutExtension(audioPath),
          tempo: result['result']['details']['tempo'] ?? 120,
        ),
      );

      _currentProject = project;
      _projectController.add(project);
      _progressReporter.complete('MIDI extraction complete');

      return project;
    } catch (e) {
      _progressReporter.error('Failed to extract MIDI: $e');
      rethrow;
    }
  }

  /// Play a specific track from the current project.
  ///
  /// This method will:
  /// 1. Find the track by its ID in the current project
  /// 2. Start playback and update the playback state
  /// 3. Emit progress updates through the progress reporter
  ///
  /// Throws an [Exception] if no project is currently loaded.
  Future<void> playTrack(String trackId) async {
    if (_currentProject == null) {
      throw Exception('No project loaded');
    }

    final track = _currentProject!.tracks
        .firstWhere((t) => t.id == trackId);
    
    // Basic playback stub - just emit progress updates
    _isPlaying = true;
    _progressReporter.report('Starting playback of track: ${track.name}', 0.0);
    await Future.delayed(const Duration(milliseconds: 100));
    if (_isPlaying) {
      _progressReporter.report('Playing track: ${track.name}', 0.5);
    }
  }

  /// Stop the currently playing track.
  ///
  /// This method will:
  /// 1. Check if any track is currently playing
  /// 2. Stop playback if active
  /// 3. Update the playback state
  /// 4. Emit a final progress update
  Future<void> stopPlayback() async {
    if (_isPlaying) {
      _progressReporter.report('Stopping playback', 1.0);
      _isPlaying = false;
    }
  }

  /// Update the MIDI extraction settings.
  ///
  /// These settings are used to configure the extraction process
  /// when calling [extractFromAudio].
  void setExtractionSettings(MidiExtractionSettings settings) {
    _extractionSettings = settings;
  }

  /// Export the current project to a MIDI file.
  ///
  /// This method will save the current project's MIDI data to the specified path.
  /// The output file will contain all tracks and metadata from the project.
  ///
  /// Throws an [Exception] if:
  /// - No project is currently loaded
  /// - The file cannot be written
  /// - The export process fails
  Future<void> exportToFile(String outputPath) async {
    if (_currentProject == null) {
      throw Exception('No project loaded');
    }

    try {
      await MidiWriter.writeFile(_currentProject!, outputPath);
    } catch (e) {
      throw Exception('Failed to export MIDI file: $e');
    }
  }

  /// Parse notes from extraction result
  List<MidiNote> _parseNotes(List<dynamic> noteData) {
    return noteData.map((note) => MidiNote(
      pitch: note['pitch'] as int,
      velocity: note['velocity'] as int,
      startTime: (note['start_time'] as num).toDouble(),
      duration: (note['duration'] as num).toDouble(),
    )).toList();
  }

  /// Clean up resources
  void dispose() {
    _extractorBridge.dispose();
    _progressReporter.dispose();
    _projectController.close();
  }
}