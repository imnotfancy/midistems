import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:midistems/core/midi_engine/midi_engine.dart';
import 'package:midistems/core/midi_engine/models.dart';

void main() {
  late MidiEngine engine;
  late String testAudioPath;

  setUp(() async {
    engine = MidiEngine();
    await engine.initialize();
    testAudioPath = path.join(
      Directory.current.path,
      'test',
      'resources',
      'test_audio.wav',
    );
  });

  tearDown(() {
    engine.dispose();
  });

  group('MidiEngine Integration Tests', () {
    test('extracts MIDI from test audio file', () async {
      // Listen for progress updates
      final progressUpdates = <String>[];
      engine.progress.listen((update) {
        progressUpdates.add(update.message);
      });

      // Extract MIDI
      final project = await engine.extractFromAudio(testAudioPath);

      // Verify project structure
      expect(project, isNotNull);
      expect(project.tracks, isNotEmpty);
      expect(project.tracks.first.notes, isNotEmpty);

      // Verify progress reporting
      expect(progressUpdates, isNotEmpty);
      expect(
        progressUpdates.first,
        contains('Starting MIDI extraction'),
      );
      expect(
        progressUpdates.last,
        contains('MIDI extraction complete'),
      );

      // Verify note properties
      final firstNote = project.tracks.first.notes.first;
      expect(firstNote.pitch, inInclusiveRange(0, 127));
      expect(firstNote.velocity, inInclusiveRange(0, 127));
      expect(firstNote.startTime, isNonNegative);
      expect(firstNote.duration, isPositive);

      // Test MIDI export
      final outputPath = path.join(
        Directory.current.path,
        'test',
        'resources',
        'test_output.mid',
      );
      await engine.exportToFile(outputPath);

      // Verify file was created
      expect(File(outputPath).existsSync(), isTrue);
    });

    test('handles extraction errors gracefully', () async {
      // Try to extract from non-existent file
      expect(
        () => engine.extractFromAudio('nonexistent.wav'),
        throwsException,
      );
    });

    test('updates extraction settings', () {
      final settings = MidiExtractionSettings(
        onsetThreshold: 0.6,
        frameThreshold: 0.4,
        minNoteLength: 50.0,
      );
      
      expect(
        () => engine.setExtractionSettings(settings),
        returnsNormally,
      );
    });
  });
}