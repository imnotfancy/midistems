import 'dart:async';

/// Progress reporter for MIDI operations
class ProgressReporter {
  final StreamController<ProgressUpdate> _controller = StreamController<ProgressUpdate>.broadcast();
  bool _isActive = false;

  /// Stream of progress updates
  Stream<ProgressUpdate> get updates => _controller.stream;

  /// Start a new operation
  void start() {
    _isActive = true;
  }

  /// Report progress for the current operation
  void report(String message, double progress) {
    if (!_isActive) return;
    
    _controller.add(ProgressUpdate(
      message: message,
      progress: progress.clamp(0.0, 1.0),
    ));
  }

  /// Report an error
  void error(String message) {
    if (!_isActive) return;
    
    _controller.add(ProgressUpdate(
      message: message,
      progress: 1.0,
      error: message,
    ));
    _isActive = false;
  }

  /// Mark the current operation as complete
  void complete(String message) {
    if (!_isActive) return;
    
    _controller.add(ProgressUpdate(
      message: message,
      progress: 1.0,
      isComplete: true,
    ));
    _isActive = false;
  }

  /// Clean up resources
  void dispose() {
    _controller.close();
  }
}

/// Progress update for MIDI operations
class ProgressUpdate {
  /// Current status message
  final String message;

  /// Progress value (0.0 to 1.0)
  final double progress;

  /// Error message if operation failed
  final String? error;

  /// Whether the operation is complete
  final bool isComplete;

  const ProgressUpdate({
    required this.message,
    required this.progress,
    this.error,
    this.isComplete = false,
  });
}