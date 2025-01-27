// ignore_for_file: unnecessary_to_list_in_spreads

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:io';
import '../../core/midi_engine/midi_engine.dart';
import 'stem_midi_controls.dart';

class MultiStemPlayer extends StatefulWidget {
  final List<Map<String, String>> stemPaths;
  final MidiEngine midiEngine;

  const MultiStemPlayer({
    super.key,
    required this.stemPaths,
    required this.midiEngine,
  });

  @override
  State<MultiStemPlayer> createState() => _MultiStemPlayerState();
}

class _MultiStemPlayerState extends State<MultiStemPlayer> {
  final List<AudioPlayer> _players = [];
  StreamSubscription<Duration>? _positionSubscription;
  String? _error;
  bool _isInitialized = false;
  AudioPlayer? get masterPlayer => _players.isNotEmpty ? _players[0] : null;
  Duration _currentPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializePlayers();
  }

  Future<void> _initializePlayers() async {
    try {
      debugPrint('Starting player initialization');
      debugPrint('Number of stems to load: ${widget.stemPaths.length}');

      for (var i = 0; i < widget.stemPaths.length; i++) {
        final stem = widget.stemPaths[i];
        try {
          debugPrint('Initializing stem ${i + 1}/${widget.stemPaths.length}: ${stem['name']}');
          await _initializePlayer(stem).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Audio initialization timed out');
            },
          );
          
          if (i < widget.stemPaths.length - 1) {
            debugPrint('Adding delay before next stem');
            await Future.delayed(const Duration(milliseconds: 100));
          }
        } catch (e) {
          debugPrint('Error initializing player: $e');
          rethrow;
        }
      }

      debugPrint('All players loaded successfully');

      if (masterPlayer != null) {
        debugPrint('Setting up master player position subscription');
        _positionSubscription = masterPlayer!.positionStream.listen((Duration newPos) {
          if (mounted) {
            setState(() {
              _currentPosition = newPos;
            });
          }
        });
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          debugPrint('Player initialization complete');
        });
      } else {
        debugPrint('Widget no longer mounted after initialization');
      }
    } catch (e) {
      debugPrint('Error initializing audio players: $e');
      if (mounted) {
        setState(() {
          _error = 'Error loading audio files: $e';
        });
      }
    }
  }

  Future<void> _initializePlayer(Map<String, String> stem) async {
    final player = AudioPlayer();
    try {
      if (!stem.containsKey('path') || stem['path']!.isEmpty) {
        throw Exception('Invalid stem configuration: missing or empty path');
      }
      
      final filePath = stem['path']!;
      final normalizedPath = Platform.isWindows
          ? filePath.replaceAll('/', r'\')
          : filePath.replaceAll(r'\', '/');
      
      final file = File(normalizedPath);
      if (!await file.exists()) {
        throw Exception('Audio file not found: $normalizedPath');
      }

      final uri = Uri.file(normalizedPath, windows: Platform.isWindows);
      debugPrint('Creating audio source for: ${uri.toFilePath()}');
      
      final completer = Completer<void>();
      
      player.playbackEventStream.listen(
        (event) {},
        onError: (Object e, StackTrace st) {
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        },
      );
      
      final audioSource = AudioSource.uri(uri);
      debugPrint('Setting audio source with initial position');
      
      await player.setAudioSource(
        audioSource,
        initialPosition: Duration.zero,
      ).then((_) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      }).catchError((e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      });

      await completer.future;
      
      final duration = player.duration;
      if (duration == null) {
        throw Exception('Failed to load audio file - invalid format or corrupted file');
      }
      
      debugPrint('Successfully loaded audio file: ${uri.toFilePath()}');
      debugPrint('Duration: $duration');
      
      if (Platform.isWindows && !player.playing) {
        await player.seek(Duration.zero);
      }
      
      _players.add(player);
    } catch (e) {
      await player.dispose();
      debugPrint('Error loading individual audio file: $e');
      throw Exception('Failed to load audio file: ${stem['path']} - $e');
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    for (var player in _players) {
      player.dispose();
    }
    super.dispose();
  }

  Future<void> _togglePlay(int index) async {
    if (!_isInitialized) return;

    try {
      final player = _players[index];
      final isPlaying = player.playing;

      if (!isPlaying) {
        if (masterPlayer != null && masterPlayer!.playing) {
          await player.seek(_currentPosition);
        }
        await player.play();
      } else {
        await player.pause();
      }
      setState(() {});
    } catch (e) {
      debugPrint('Error toggling playback: $e');
      setState(() {
        _error = 'Error playing audio: $e';
      });
    }
  }

  Future<void> _openFileLocation(String filePath) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', ['/select,', filePath]);
      } else {
        final uri = Uri.file(filePath);
        if (!await launchUrl(uri)) {
          debugPrint("Could not open file location: $filePath");
        }
      }
    } catch (e) {
      debugPrint('Error opening file location: $e');
      setState(() {
        _error = 'Error opening file location: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _isInitialized = false;
                    _players.clear();
                  });
                  _initializePlayers();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Loading'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading audio files...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ...widget.stemPaths.asMap().entries.map((entry) {
              final index = entry.key;
              final stem = entry.value;
              final isLoaded = index < _players.length;
              final isLoading = index == _players.length;
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: isLoaded
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.pending, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${stem['name']} stem',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isLoaded
                            ? null
                            : Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      );
    }

    if (widget.stemPaths.isEmpty) {
      return const Center(child: Text('No stems to play.'));
    }
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
              maxWidth: constraints.maxWidth,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(widget.stemPaths.length, (index) {
                final stem = widget.stemPaths[index];
                final isPlaying = _players[index].playing;
                final name = stem['name']!;
                final path = stem['path']!;
                
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        title: Text('$name stem'),
                        subtitle: Text(File(path).path),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                              onPressed: () => _togglePlay(index),
                              tooltip: 'Play/Pause Audio',
                            ),
                            IconButton(
                              icon: const Icon(Icons.folder_open),
                              onPressed: () => _openFileLocation(path),
                              tooltip: 'Open File Location',
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: StemMidiControls(
                          stemPath: path,
                          stemName: name,
                          midiEngine: widget.midiEngine,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}