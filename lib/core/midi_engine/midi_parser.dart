import 'dart:io';
import 'dart:typed_data';
import 'models.dart';

/// Class responsible for parsing MIDI files and extracting note data
class MidiParser {
  /// Parse a MIDI file and extract note data
  static Future<List<MidiNote>> parseFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('MIDI file not found: $filePath');
    }

    final bytes = await file.readAsBytes();
    final data = ByteData.view(bytes.buffer);
    final notes = <MidiNote>[];

    try {
      var offset = 0;
      
      // Read MIDI header
      final headerChunk = _readChunk(data, offset);
      offset = headerChunk.nextOffset;

      // Verify MIDI format
      if (headerChunk.id != 'MThd') {
        throw Exception('Invalid MIDI file: Missing MThd header');
      }

      // Read track chunks
      while (offset < data.lengthInBytes) {
        final trackChunk = _readChunk(data, offset);
        if (trackChunk.id == 'MTrk') {
          final trackNotes = _parseTrackChunk(data, trackChunk);
          notes.addAll(trackNotes);
        }
        offset = trackChunk.nextOffset;
      }

      return notes;
    } catch (e) {
      throw Exception('Failed to parse MIDI file: $e');
    }
  }

  /// Read a MIDI chunk header
  static ({String id, int length, int nextOffset}) _readChunk(ByteData data, int offset) {
    final id = String.fromCharCodes([
      data.getUint8(offset),
      data.getUint8(offset + 1),
      data.getUint8(offset + 2),
      data.getUint8(offset + 3),
    ]);

    final length = data.getUint32(offset + 4);
    final nextOffset = offset + 8 + length;

    return (
      id: id,
      length: length,
      nextOffset: nextOffset,
    );
  }

  /// Parse a MIDI track chunk and extract notes
  static List<MidiNote> _parseTrackChunk(ByteData data, ({String id, int length, int nextOffset}) chunk) {
    final notes = <MidiNote>[];
    var offset = chunk.nextOffset - chunk.length;
    var time = 0.0;
    final activeNotes = <int, ({int pitch, int velocity, double startTime})>{};

    while (offset < chunk.nextOffset) {
      // Read delta time
      final deltaTime = _readVariableLengthQuantity(data, offset);
      offset = deltaTime.nextOffset;
      time += deltaTime.value / 480; // Assuming standard PPQN

      // Read event
      final status = data.getUint8(offset++);
      final isNoteOn = (status & 0xF0) == 0x90;
      final isNoteOff = (status & 0xF0) == 0x80;
      
      // Note on/off events
      if (isNoteOn || isNoteOff) {
        final pitch = data.getUint8(offset++);
        final velocity = data.getUint8(offset++);
        
        // Note on with velocity > 0
        if (isNoteOn && velocity > 0) {
          activeNotes[pitch] = (
            pitch: pitch,
            velocity: velocity,
            startTime: time,
          );
        }
        // Note off or note on with velocity 0
        else {
          final startNote = activeNotes.remove(pitch);
          if (startNote != null) {
            notes.add(MidiNote(
              pitch: startNote.pitch,
              velocity: startNote.velocity,
              startTime: startNote.startTime,
              duration: time - startNote.startTime,
            ));
          }
        }
      }
      // Skip other events
      else if (status == 0xFF) {
        // Meta event
        offset++; // Skip type
        final length = data.getUint8(offset++);
        offset += length;
      }
      else if ((status & 0xF0) == 0xC0 || (status & 0xF0) == 0xD0) {
        // Program change or Channel pressure
        offset++;
      }
      else {
        // Other events with 2 data bytes
        offset += 2;
      }
    }

    return notes;
  }

  /// Read a variable-length quantity from MIDI data
  static ({int value, int nextOffset}) _readVariableLengthQuantity(ByteData data, int offset) {
    var value = 0;
    var currentByte = 0;
    
    do {
      currentByte = data.getUint8(offset++);
      value = (value << 7) | (currentByte & 0x7F);
    } while ((currentByte & 0x80) != 0);

    return (
      value: value,
      nextOffset: offset,
    );
  }
}