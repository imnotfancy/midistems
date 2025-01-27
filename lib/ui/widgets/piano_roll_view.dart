import 'package:flutter/material.dart';
import '../../core/midi_engine/models.dart';

/// Widget for displaying MIDI notes in a piano roll format
class PianoRollView extends StatelessWidget {
  final MidiTrack track;
  final bool isPlaying;
  final double currentTime;
  final double height;
  final double pixelsPerSecond;
  final double noteHeight;

  const PianoRollView({
    super.key,
    required this.track,
    this.isPlaying = false,
    this.currentTime = 0.0,
    this.height = 300.0,
    this.pixelsPerSecond = 100.0,
    this.noteHeight = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Piano keys background
          _buildPianoKeys(context),
          
          // Grid lines
          _buildGridLines(context),
          
          // MIDI notes
          _buildNotes(context),
          
          // Playhead
          if (isPlaying) _buildPlayhead(context),
        ],
      ),
    );
  }

  Widget _buildPianoKeys(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              right: BorderSide(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          child: Column(
            children: List.generate(128, (index) {
              final isBlackKey = [1, 3, 6, 8, 10].contains(index % 12);
              return Container(
                height: noteHeight,
                color: isBlackKey
                    ? Colors.black87
                    : Colors.white,
                child: index % 12 == 0
                    ? Center(
                        child: Text(
                          'C${index ~/ 12 - 1}',
                          style: TextStyle(
                            fontSize: 8,
                            color: isBlackKey ? Colors.white : Colors.black,
                          ),
                        ),
                      )
                    : null,
              );
            }),
          ),
        ),
        Expanded(
          child: Container(
            color: Theme.of(context).colorScheme.surface,
          ),
        ),
      ],
    );
  }

  Widget _buildGridLines(BuildContext context) {
    return CustomPaint(
      painter: GridPainter(
        color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
        pixelsPerSecond: pixelsPerSecond,
        noteHeight: noteHeight,
      ),
    );
  }

  Widget _buildNotes(BuildContext context) {
    return Positioned.fill(
      left: 40, // Piano keys width
      child: CustomPaint(
        painter: NotesPainter(
          notes: track.notes,
          pixelsPerSecond: pixelsPerSecond,
          noteHeight: noteHeight,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildPlayhead(BuildContext context) {
    return Positioned(
      left: 40 + currentTime * pixelsPerSecond,
      top: 0,
      bottom: 0,
      child: Container(
        width: 2,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

/// Painter for grid lines
class GridPainter extends CustomPainter {
  final Color color;
  final double pixelsPerSecond;
  final double noteHeight;

  GridPainter({
    required this.color,
    required this.pixelsPerSecond,
    required this.noteHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    // Vertical lines (time divisions)
    for (var x = 0.0; x < size.width; x += pixelsPerSecond / 4) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Horizontal lines (note divisions)
    for (var y = 0.0; y < size.height; y += noteHeight) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) =>
      color != oldDelegate.color ||
      pixelsPerSecond != oldDelegate.pixelsPerSecond ||
      noteHeight != oldDelegate.noteHeight;
}

/// Painter for MIDI notes
class NotesPainter extends CustomPainter {
  final List<MidiNote> notes;
  final double pixelsPerSecond;
  final double noteHeight;
  final Color color;

  NotesPainter({
    required this.notes,
    required this.pixelsPerSecond,
    required this.noteHeight,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final note in notes) {
      final rect = Rect.fromLTWH(
        note.startTime * pixelsPerSecond,
        (127 - note.pitch) * noteHeight,
        note.duration * pixelsPerSecond,
        noteHeight,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(NotesPainter oldDelegate) =>
      notes != oldDelegate.notes ||
      pixelsPerSecond != oldDelegate.pixelsPerSecond ||
      noteHeight != oldDelegate.noteHeight ||
      color != oldDelegate.color;
}