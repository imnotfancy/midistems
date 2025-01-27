import 'dart:io';
import 'dart:typed_data';
import 'models.dart';

/// Class responsible for writing MIDI files
class MidiWriter {
  static const int _midiFormat = 1; // Multiple tracks
  static const int _division = 480; // Standard PPQN

  /// Write a MidiProject to a MIDI file
  static Future<void> writeFile(MidiProject project, String filePath) async {
    final builder = BytesBuilder();
    
    try {
      // Write header chunk
      _writeHeaderChunk(builder, project.tracks.length);

      // Write track chunks
      for (final track in project.tracks) {
        _writeTrackChunk(builder, track, project.metadata);
      }

      // Write to file
      final file = File(filePath);
      await file.writeAsBytes(builder.takeBytes());
    } catch (e) {
      throw Exception('Failed to write MIDI file: $e');
    }
  }

  /// Write MIDI header chunk
  static void _writeHeaderChunk(BytesBuilder builder, int numTracks) {
    // Chunk ID: MThd
    builder.add([0x4D, 0x54, 0x68, 0x64]);
    
    // Chunk length: 6
    builder.add([0x00, 0x00, 0x00, 0x06]);
    
    // Format: 1 (multiple tracks)
    builder.add([0x00, _midiFormat]);
    
    // Number of tracks
    builder.add([0x00, numTracks]);
    
    // Division (PPQN)
    builder.add([(_division >> 8) & 0xFF, _division & 0xFF]);
  }

  /// Write MIDI track chunk
  static void _writeTrackChunk(
    BytesBuilder builder,
    MidiTrack track,
    MidiMetadata metadata,
  ) {
    final trackBuilder = BytesBuilder();
    
    // Write tempo meta event
    _writeMetaEvent(
      trackBuilder,
      0, // Delta time
      0x51, // Tempo
      _tempoToBytes(metadata.tempo),
    );

    // Write time signature if specified
    final numerator = metadata.timeSignatureNumerator;
    final denominator = metadata.timeSignatureDenominator;
    if (numerator != null && denominator != null &&
        numerator > 0 && denominator > 0) {
      _writeMetaEvent(
        trackBuilder,
        0,
        0x58, // Time signature
        [
          numerator,
          _log2(denominator),
          24, // MIDI clocks per metronome click
          8,  // 32nd notes per quarter note
        ],
      );
    }

    // Sort notes by start time
    final sortedNotes = List<MidiNote>.from(track.notes)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    // Write note events
    var currentTime = 0.0;
    for (final note in sortedNotes) {
      final deltaTime = (note.startTime - currentTime) * _division;
      currentTime = note.startTime;

      // Note on
      _writeVarLength(trackBuilder, deltaTime.round());
      trackBuilder.add([
        0x90 | (track.channel & 0x0F), // Note on, channel
        note.pitch & 0x7F,
        note.velocity & 0x7F,
      ]);

      // Note off
      final duration = note.duration * _division;
      _writeVarLength(trackBuilder, duration.round());
      trackBuilder.add([
        0x80 | (track.channel & 0x0F), // Note off, channel
        note.pitch & 0x7F,
        0x40, // Release velocity
      ]);
    }

    // Write end of track
    _writeMetaEvent(trackBuilder, 0, 0x2F, []);

    // Write track chunk header
    builder.add([0x4D, 0x54, 0x72, 0x6B]); // MTrk
    final length = trackBuilder.length;
    builder.add([
      (length >> 24) & 0xFF,
      (length >> 16) & 0xFF,
      (length >> 8) & 0xFF,
      length & 0xFF,
    ]);

    // Write track data
    builder.add(trackBuilder.takeBytes());
  }

  /// Write variable length value
  static void _writeVarLength(BytesBuilder builder, int value) {
    if (value < 0) value = 0;
    
    final bytes = <int>[];
    bytes.add(value & 0x7F);
    
    while ((value >>= 7) > 0) {
      bytes.add((value & 0x7F) | 0x80);
    }

    // Convert reversed bytes to list
    builder.add(bytes.reversed.toList());
  }

  /// Write meta event
  static void _writeMetaEvent(
    BytesBuilder builder,
    int deltaTime,
    int type,
    List<int> data,
  ) {
    _writeVarLength(builder, deltaTime);
    builder.add([0xFF, type]); // Meta event marker and type
    _writeVarLength(builder, data.length);
    builder.add(data);
  }

  /// Convert tempo (BPM) to MIDI tempo bytes (microseconds per quarter note)
  static List<int> _tempoToBytes(int bpm) {
    final microsecondsPerBeat = (60000000 / bpm).round();
    return [
      (microsecondsPerBeat >> 16) & 0xFF,
      (microsecondsPerBeat >> 8) & 0xFF,
      microsecondsPerBeat & 0xFF,
    ];
  }

  /// Calculate log base 2 of a number (for time signature)
  static int _log2(int value) {
    var result = 0;
    while (value > 1) {
      value ~/= 2;
      result++;
    }
    return result;
  }
}