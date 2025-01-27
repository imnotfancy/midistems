// ignore_for_file: unused_import

import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/midi_engine/midi_engine.dart';
import '../../core/midi_engine/models.dart';
import '../../core/midi_engine/progress_reporter.dart';
import 'piano_roll_view.dart';

class StemMidiControls extends StatefulWidget {
  final String stemPath;
  final String stemName;
  final MidiEngine midiEngine;

  const StemMidiControls({
    super.key,
    required this.stemPath,
    required this.stemName,
    required this.midiEngine,
  });

  @override
  State<StemMidiControls> createState() => _StemMidiControlsState();
}

class _StemMidiControlsState extends State<StemMidiControls> {
  MidiProject? _midiProject;
  bool _isGenerating = false;
  bool _isPlaying = false;
  String? _error;
  double _currentTime = 0.0;
  StreamSubscription? _progressSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToProgress();
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToProgress() {
    _progressSubscription = widget.midiEngine.progress.listen(
      (update) {
        setState(() {
          if (update.error?.isNotEmpty == true) {
            _error = update.error;
            _isGenerating = false;
          } else if (update.isComplete == true) {
            _isGenerating = false;
          }
        });
      },
    );
  }

  Future<void> _generateMidi() async {
    if (_isGenerating) return;

    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      final project = await widget.midiEngine.extractFromAudio(widget.stemPath);
      if (mounted) {
        setState(() {
          _midiProject = project;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to generate MIDI: $e';
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _togglePlayback() async {
    if (_midiProject == null || _midiProject!.tracks.isEmpty) return;

    try {
      if (_isPlaying) {
        await widget.midiEngine.stopPlayback();
        setState(() {
          _isPlaying = false;
        });
      } else {
        setState(() {
          _isPlaying = true;
          _currentTime = 0.0;
        });
        await widget.midiEngine.playTrack(_midiProject!.tracks.first.id);
        setState(() {
          _isPlaying = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Playback error: $e';
        _isPlaying = false;
      });
    }
  }

  Future<void> _exportMidi() async {
    if (_midiProject == null) return;

    try {
      final outputPath = '${widget.stemPath}_generated.mid';
      await widget.midiEngine.exportToFile(outputPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('MIDI exported to: $outputPath'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export MIDI: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // MIDI Generation Button
        if (_midiProject == null)
          ElevatedButton.icon(
            onPressed: _isGenerating ? null : _generateMidi,
            icon: _isGenerating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.music_note),
            label: Text(_isGenerating ? 'Generating MIDI...' : 'Generate MIDI'),
          ),

        // Error Display
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),

        // MIDI Controls and Piano Roll
        if (_midiProject != null && _midiProject!.tracks.isNotEmpty) ...[
          const Divider(),
          // Playback Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: _togglePlayback,
                tooltip: _isPlaying ? 'Pause' : 'Play',
              ),
              IconButton(
                icon: const Icon(Icons.stop),
                onPressed: _isPlaying ? () => widget.midiEngine.stopPlayback() : null,
                tooltip: 'Stop',
              ),
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: _exportMidi,
                tooltip: 'Export MIDI',
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Piano Roll View
          PianoRollView(
            track: _midiProject!.tracks.first,
            isPlaying: _isPlaying,
            currentTime: _currentTime,
            height: 200,
          ),
        ],
      ],
    );
  }
}