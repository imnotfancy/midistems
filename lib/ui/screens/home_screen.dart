import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import '../../services/audio_processing/audio_service.dart';
import '../../core/midi_engine/midi_engine.dart';
import '../widgets/lol_loading_dialog.dart';
import '../widgets/multi_stem_player.dart';
import '../../data/lol_taglines.dart';

const _processingMessages = [
  'Loading PyTorch engine...',
  'Initializing SoundFile processor...',
  'Loading Demucs model...',
  'Starting stem separation...',
  'Processing audio file...',
  'Applying source separation...',
  'Almost there, hang tight...',
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioService _audioService = AudioService();
  final MidiEngine _midiEngine = MidiEngine();
  String? _selectedFilePath;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeMidiEngine();
  }

  Future<void> _initializeMidiEngine() async {
    try {
      await _midiEngine.initialize();
    } catch (e) {
      setState(() {
        _statusMessage = 'Error initializing MIDI engine: $e';
      });
    }
  }

  @override
  void dispose() {
    _midiEngine.dispose();
    super.dispose();
  }

  Future<void> _selectFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wav', 'mp3', 'flac', 'ogg'],
      );

      if (result != null) {
        final filePath = result.files.single.path;
        // Normalize the file path
        final normalizedPath = path.normalize(filePath!);
        
        // Verify file exists and is readable
        final file = File(normalizedPath);
        if (!await file.exists()) {
          setState(() {
            _statusMessage = 'Error: Selected file does not exist';
          });
          return;
        }

        setState(() {
          _selectedFilePath = normalizedPath;
          _statusMessage = 'Selected file: ${result.files.single.name}';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error selecting file: $e';
      });
    }
  }

  Future<void> _showStemPlayer(Map<String, dynamic> result) async {
    try {
      final Map<String, String> stems = (result['stems']! as Map<String, dynamic>).cast<String, String>();
      
      final stemsList = stems.entries.map((e) {
        final name = path.basenameWithoutExtension(e.key);
        // Convert forward slashes to platform-specific separator
        final stemPath = e.value.replaceAll('/', Platform.pathSeparator);
        
        // Verify the stem file exists
        final stemFile = File(stemPath);
        if (!stemFile.existsSync()) {
          throw Exception('Stem file not found: $stemPath');
        }
        
        // Verify the file is readable
        if (!stemFile.lengthSync().isFinite) {
          throw Exception('Invalid stem file: $stemPath');
        }
        
        return {
          'name': name,
          'path': stemPath
        };
      }).toList();

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => Dialog(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                width: constraints.maxWidth * 0.8,
                height: constraints.maxHeight * 0.8,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Separated Stems',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: MultiStemPlayer(
                        stemPaths: stemsList,
                        midiEngine: _midiEngine,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _statusMessage = 'Error showing stem player: $e';
      });
    }
  }

  Future<void> _processStemSeparation() async {
    if (_selectedFilePath == null) {
      setState(() {
        _statusMessage = 'Please select an audio file first';
      });
      return;
    }

    // Show the loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => LolLoadingDialog(
        title: 'Separating Stems',
        messages: [
          ...domainTaglines,
          ..._processingMessages,
        ],
      ),
    );

    setState(() {
      _statusMessage = 'Starting stem separation...';
    });

    String? errorMessage;
    String? resultMessage;
    Map<String, dynamic>? result;
    
    try {
      // Get application documents directory and create stems subdirectory
      final appDir = await getApplicationDocumentsDirectory();
      final stemsBaseDir = Directory(path.join(appDir.path, 'stems'));
      await stemsBaseDir.create(recursive: true);

      // Create a unique directory for this file's stems
      final fileName = path.basenameWithoutExtension(_selectedFilePath!);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final stemsDir = path.join(stemsBaseDir.path, '${fileName}_$timestamp');
      
      result = await _audioService.separateStems(
        inputPath: _selectedFilePath!,
        outputDir: stemsDir,
      );

      resultMessage = 'Stem separation complete!\n'
          'Stems saved to: $stemsDir\n'
          'Generated stems: ${(result['stems'] as Map).keys.join(', ')}';
    } catch (e) {
      // Extract actual error message from the full exception
      final fullError = e.toString();
      final errorMatch = RegExp(r'Exception: (.+?)\nINFO:').firstMatch(fullError);
      errorMessage = errorMatch?.group(1) ?? 'Failed to separate stems';
      
      // Extract progress messages
      final infoMessages = RegExp(r'INFO: ([^\n]+)')
          .allMatches(fullError)
          .map((m) => m.group(1) ?? '')
          .where((msg) => msg.isNotEmpty)
          .toList();

      if (!mounted) return;

      // Close the current dialog
      Navigator.of(context).pop();

      // Show error dialog with progress info
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => LolLoadingDialog(
          title: 'Separation Failed',
          messages: [
            ...infoMessages,
            'Oops! Something went wrong...',
            'Checking the error logs...',
            'Attempting to recover...',
          ],
          errorMessage: errorMessage,
          onClose: () {
            Navigator.of(context).pop();
            setState(() {
              _statusMessage = 'Error processing audio: $errorMessage';
            });
          },
        ),
      );
      return;
    }

    if (!mounted) return;

    // Close the current dialog and wait for animation
    Navigator.of(context).pop();
    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      _statusMessage = resultMessage ?? 'Stem separation completed';
    });

    // Show the MultiStemPlayer dialog
    if (!mounted) return;
    await _showStemPlayer(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MidiStems'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Separate Audio into Stems',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Supported formats: WAV, MP3, FLAC, OGG',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: const Icon(Icons.audio_file),
                label: const Text('Select Audio File'),
                onPressed: _selectFile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.splitscreen),
                label: const Text('Separate Stems'),
                onPressed: _selectedFilePath == null ? null : _processStemSeparation,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              if (_statusMessage.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 20),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}