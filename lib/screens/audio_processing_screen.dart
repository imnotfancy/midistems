import 'package:flutter/material.dart';
import 'package:midistems/services/rust_audio_service.dart';

class AudioProcessingScreen extends StatefulWidget {
  const AudioProcessingScreen({Key? key}) : super(key: key);

  @override
  _AudioProcessingScreenState createState() => _AudioProcessingScreenState();
}

class _AudioProcessingScreenState extends State<AudioProcessingScreen> {
  final RustAudioService _audioService = RustAudioService();
  bool _isInitialized = false;
  String _statusMessage = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initializeAudioEngine();
  }

  @override
  void dispose() {
    _cleanupAudioEngine();
    super.dispose();
  }

  Future<void> _initializeAudioEngine() async {
    try {
      final success = _audioService.initialize();
      setState(() {
        _isInitialized = success;
        _statusMessage = success
            ? 'Audio engine initialized successfully'
            : 'Failed to initialize audio engine: ${_audioService.getLastErrorMessage()}';
      });
    } catch (e) {
      setState(() {
        _isInitialized = false;
        _statusMessage = 'Error initializing audio engine: $e';
      });
    }
  }

  void _cleanupAudioEngine() {
    if (_isInitialized) {
      _audioService.cleanup();
    }
  }

  Future<void> _loadAudioFile() async {
    if (!_isInitialized) {
      setState(() {
        _statusMessage = 'Audio engine not initialized';
      });
      return;
    }

    // In a real app, you would use a file picker here
    const filePath = '/path/to/audio/file.mp3';

    try {
      final success = _audioService.loadAudioFile(filePath);
      setState(() {
        _statusMessage = success
            ? 'Audio file loaded successfully'
            : 'Failed to load audio file: ${_audioService.getLastErrorMessage()}';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error loading audio file: $e';
      });
    }
  }
  
  Future<void> _testAudioSystem() async {
    if (!_isInitialized) {
      setState(() {
        _statusMessage = 'Audio engine not initialized';
      });
      return;
    }

    try {
      final result = _audioService.testAudioSystem();
      setState(() {
        _statusMessage = 'Audio test result: $result';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error testing audio system: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Processing'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _statusMessage,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isInitialized ? _loadAudioFile : null,
              child: const Text('Load Audio File'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isInitialized ? _testAudioSystem : null,
              child: const Text('Test Audio System'),
            ),
          ],
        ),
      ),
    );
  }
}