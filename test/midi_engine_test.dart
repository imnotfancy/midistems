import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:midistems/core/midi_engine/midi_engine.dart';
import 'package:midistems/core/midi_engine/models.dart';

void main() {
  late MidiEngine engine;

  setUp(() async {
    engine = MidiEngine();
    await engine.initialize();
  });

  tearDown(() {
    engine.dispose();
  });

  group('MidiEngine', () {
    test('initializes successfully', () {
      expect(engine, isNotNull);
    });

    test('updates extraction settings', () {
      final settings = MidiExtractionSettings(
        onsetThreshold: 0.6,
        frameThreshold: 0.4,
        minNoteLength: 50,
      );
      
      engine.setExtractionSettings(settings);
      // Since settings are private, we can only verify no errors occurred
      expect(() => engine.setExtractionSettings(settings), returnsNormally);
    });

    test('throws when accessing project before extraction', () {
      expect(
        () => engine.playTrack('nonexistent'),
        throwsA(isA<StateError>()),
      );
    });

    test('throws when exporting without project', () {
      expect(
        () => engine.exportToFile('output.mid'),
        throwsA(isA<StateError>()),
      );
    });

    test('emits project updates', () async {
      expect(engine.projectUpdates, emits(isA<MidiProject>()));
      
      // Create a test audio file path
      final audioPath = path.join(
        path.current,
        'test',
        'resources',
        'test_audio.wav'
      );

      // This will fail since we don't have actual audio file,
      // but it should still emit a project before throwing
      try {
        await engine.extractFromAudio(audioPath);
      } catch (_) {
        // Expected to throw
      }
    });
  });

  group('MidiProject', () {
    test('creates from json', () {
      final Map<String, dynamic> json = {
        'id': 'test-id',
        'tracks': [
          {
            'id': 'track-1',
            'name': 'Test Track',
            'notes': [
              {
                'pitch': 60,
                'velocity': 100,
                'startTime': 0.0,
                'duration': 1.0,
              }
            ],
            'channel': 0,
            'muted': false,
            'soloed': false,
          }
        ],
        'metadata': {
          'title': 'Test Project',
          'artist': 'Test Artist',
          'tempo': 120,
          'timeSignatureNumerator': 4,
          'timeSignatureDenominator': 4,
        }
      };

      final project = MidiProject.fromJson(json);
      expect(project.id, equals('test-id'));
      expect(project.tracks.length, equals(1));
      expect(project.tracks.first.notes.length, equals(1));
      expect(project.metadata.title, equals('Test Project'));
    });

    test('converts to json', () {
      final project = MidiProject(
        id: 'test-id',
        tracks: [
          MidiTrack(
            id: 'track-1',
            name: 'Test Track',
            notes: [
              MidiNote(
                pitch: 60,
                velocity: 100,
                startTime: 0.0,
                duration: 1.0,
              ),
            ],
          ),
        ],
        metadata: const MidiMetadata(
          title: 'Test Project',
          artist: 'Test Artist',
        ),
      );

      final json = project.toJson();
      expect(json['id'], equals('test-id'));
      expect(json['tracks'].length, equals(1));
      expect(json['metadata']['title'], equals('Test Project'));
    });
  });
}