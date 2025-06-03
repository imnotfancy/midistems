import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p; // Aliased to p to avoid conflict
import 'dart:io';
// import '../../services/audio_processing/audio_service.dart'; // Replaced by RustService
import '../../services/rust_service.dart'; // Import RustService
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
  // final AudioService _audioService = AudioService(); // Replaced by RustService
  final RustService _rustService = RustService(); // Instantiate RustService
  final MidiEngine _midiEngine = MidiEngine(); // Still needed for MIDI playback/parsing
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
        final normalizedPath = p.normalize(filePath!); // Use alias p
        
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
      // The result from RustService.separateStems is expected to be Map<String, dynamic>
      // where the actual stems map is under a 'stems' key: {'stems': {'vocals': 'path/to/vocals.wav', ...}}
      final Map<String, dynamic>? stemsData = result['stems'] as Map<String, dynamic>?;

      if (stemsData == null) {
        throw Exception("Stem data is missing in the result from Rust service.");
      }
      final Map<String, String> stems = stemsData.cast<String, String>();
      
      final stemsList = stems.entries.map((e) {
        // e.key is the stem name (e.g., "vocals"), e.value is the path
        final name = e.key;
        // Paths from Rust/Python should ideally be absolute and correct.
        // Normalization might still be good.
        final stemPath = p.normalize(e.value.replaceAll('/', Platform.pathSeparator));
        
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
    Map<String, dynamic>? rustCallResult; // This will hold {'stems': {...}}
    
    try {
      // Get application documents directory and create stems subdirectory for output
      final appDir = await getApplicationDocumentsDirectory();
      final stemsBaseDir = Directory(p.join(appDir.path, 'stems_output')); // Changed name slightly
      await stemsBaseDir.create(recursive: true);

      // Create a unique directory for this specific separation task's stems
      final fileName = p.basenameWithoutExtension(_selectedFilePath!);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // The output directory that Rust/Python will write into
      final outputDirForStems = p.join(stemsBaseDir.path, '${fileName}_$timestamp');
      await Directory(outputDirForStems).create(recursive: true);
      
      // Call the Rust FFI service
      rustCallResult = await _rustService.separateStems(
        inputAudioPath: _selectedFilePath!,
        outputDirPath: outputDirForStems, // Pass the created directory
      );

      // The structure of rustCallResult is expected to be: {'stems': {'vocals': 'path/to/vocals.wav', ...}}
      // The paths within 'stems' should be absolute paths to the files written by the Python script.
      if (rustCallResult['stems'] == null || (rustCallResult['stems'] as Map).isEmpty) {
        throw Exception("Stem separation via Rust FFI did not return any stem paths.");
      }

      resultMessage = 'Stem separation complete!\n'
          'Stems saved in: $outputDirForStems\n' // The Python script saves them inside this dir
          'Generated stems: ${(rustCallResult['stems'] as Map).keys.join(', ')}';

    } catch (e) {
      final fullError = e.toString();
      // errorMessage = fullError; // Simpler error message handling for now
      // Let's try to make it more specific if it's an Exception from RustService
      if (e is Exception) {
        errorMessage = e.toString().replaceFirst("Exception: ", "");
      } else {
        errorMessage = 'Failed to separate stems: $fullError';
      }
      
      List<String> infoMessages = []; // Placeholder if needed for LolLoadingDialog

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      showDialog(
        context: context,
        barrierDismissible: false, // Keep it consistent
        builder: (_) => LolLoadingDialog( // Reusing for error display
          title: 'Separation Failed',
          messages: [ // Simplified messages for FFI error
            'An error occurred during stem separation.',
            'Please check the details below.',
            ...infoMessages, // if any were populated
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
    Navigator.of(context).pop(); // Close loading dialog
    await Future.delayed(const Duration(milliseconds: 300)); // Keep delay

    setState(() {
      _statusMessage = resultMessage ?? 'Stem separation completed (Rust FFI)';
    });

    // Show the MultiStemPlayer dialog with the result from Rust FFI
    if (!mounted) return;
    // rustCallResult already contains {'stems': {...}}
    await _showStemPlayer(rustCallResult!);
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