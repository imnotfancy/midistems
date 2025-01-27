# MIDI Engine Implementation

## Overview
The MIDI engine will be responsible for extracting MIDI data from audio files, providing a crucial feature alongside the existing stem separation functionality. This document outlines the technical implementation details for the MIDI extraction and processing capabilities.

## Architecture Components

### 1. Core Components
- **MidiExtractor**: Main class responsible for audio-to-MIDI conversion
- **MidiProcessor**: Handles post-processing of extracted MIDI data
- **MidiPlayer**: Manages MIDI playback functionality
- **MidiExporter**: Handles exporting MIDI to standard MIDI file format (.mid)

### 2. Integration Points
- Integration with `AudioService` for synchronized audio/MIDI playback
- Connection to `MultiStemPlayer` for visual MIDI track representation
- FFI bridge for Python-based MIDI extraction (similar to current audio processing)

## Technical Requirements

### 1. Dependencies
- **Python Libraries**
  - `librosa`: Audio processing and feature extraction
  - `pretty_midi`: MIDI file creation and manipulation
  - `basic_pitch` (Spotify's ML model): For monophonic pitch detection
  - `tensorflow`: Required for ML-based MIDI extraction

### 2. Flutter Dependencies
```yaml
dependencies:
  flutter_midi: ^1.0.0  # For MIDI playback
  midi_util: ^1.0.0    # MIDI file manipulation
```

## Implementation Progress

### Completed Components
1. **Core Architecture**
   - Implemented data models with JSON serialization
   - Created FFI bridge structure for Dart-Python communication
   - Added progress reporting system
   - Implemented MIDI file writer
   - Set up test infrastructure

2. **Data Models**
   - MidiProject: Top-level container with JSON support
   - MidiTrack: Represents individual MIDI tracks
   - MidiNote: Contains note data (pitch, velocity, timing)
   - Settings models for extraction and playback
   - Progress reporting models

3. **Test Infrastructure**
   - Integration test framework
   - Test audio file generation
   - MIDI extraction test cases
   - Mock audio files for testing

### Current Issues
1. **Python Environment Setup**
   ```
   ModuleNotFoundError: No module named 'basic_pitch'
   ```
   - Basic Pitch module not found during initialization
   - Need to install Basic Pitch from forked repository
   - Python virtual environment needs proper setup

2. **Path Resolution**
   - Fixed script path resolution in MidiExtractorBridge
   - Now using project's working directory for Python scripts

3. **Integration Testing**
   - Tests failing due to Python module issues
   - Need to ensure consistent test environment
   - Add more comprehensive test cases

### Next Immediate Steps
1. Fix Python environment:
   ```bash
   cd python/basic_pitch_fork
   pip install -e .
   ```

2. Complete MIDI extraction implementation:
   - Finish Python extractor implementation
   - Add proper error handling
   - Implement progress reporting

3. Enhance test coverage:
   - Add unit tests for all components
   - Implement integration tests
   - Add performance benchmarks

### TODO List

1. **Code Issues to Fix**
   - midi_engine.dart (6 issues)
     - [x] Fix unused import: 'dart:typed_data'
     - [x] Implement usage of _extractionSettings field in MIDI extraction
     - [x] Implement usage of _playbackSettings field in playback
     - [x] Use midiPath variable in extractFromAudio method
     - [x] Implement MIDI file parsing for note extraction
     - [x] Implement MIDI file export functionality

   - midi_extractor_bridge.dart (4 issues)
     - [x] Review and optimize FFI memory management
     - [x] Add error handling for Python initialization failures
     - [x] Add proper cleanup of Python resources
     - [x] Implement progress reporting for long operations

   - midi_parser.dart (New Component)
     - [x] Implement MIDI file header parsing
     - [x] Implement MIDI track chunk parsing
     - [x] Extract note data with timing information
     - [x] Handle variable-length quantities
     - [x] Add error handling and validation

   - midi_writer.dart (New Component)
     - [x] Implement MIDI file header writing
     - [x] Implement MIDI track chunk writing
     - [x] Support tempo and time signature metadata
     - [x] Handle variable-length quantities
     - [x] Add error handling and validation

   - progress_reporter.dart (New Component)
     - [x] Implement progress update stream
     - [x] Add progress reporting for MIDI extraction
     - [x] Add progress reporting for MIDI playback
     - [x] Add progress reporting for MIDI export
     - [x] Handle error reporting and completion states
     - [x] Implement MIDI file header writing
     - [x] Implement MIDI track chunk writing
     - [x] Support tempo and time signature metadata
     - [x] Handle variable-length quantities
     - [x] Add error handling and validation

   - home_screen.dart (15 issues)
     - [x] Add MidiEngine initialization
     - [x] Handle MIDI generation errors
     - [x] Add progress reporting for MIDI operations
     - [x] Implement proper error handling

   - multi_stem_player.dart (22 issues)
     - [x] Integrate MIDI controls with audio playback
     - [x] Add MIDI visualization
     - [x] Implement MIDI track controls
     - [x] Add export functionality

   - stem_midi_controls.dart (3 issues)
     - [x] Add progress indicators
     - [x] Implement error handling
     - [x] Add MIDI preview functionality

   - midi_engine_test.dart (2 issues)
     - [ ] Implement comprehensive test suite
     - [ ] Add mock audio files for testing

2. **Feature Implementation**
    - [x] Implement piano roll visualization
    - [x] Add MIDI file parsing
    - [x] Add MIDI export functionality
    - [x] Implement playback parameter controls
    - [ ] Add batch processing support

3. **Integration Tasks**
    - [x] Synchronize audio and MIDI playback
    - [x] Add MIDI visualization to stem player
    - [x] Implement export settings dialog
    - [x] Add progress reporting system

4. **UI Components**
    - [x] Piano roll visualization widget
    - [x] MIDI controls integration
    - [x] Progress reporting UI
    - [x] Error handling and feedback
    - [x] File export dialogs

4. **Testing and Optimization**
   - [ ] Add unit tests for all components
   - [ ] Add integration tests
   - [ ] Optimize memory usage
   - [ ] Add performance benchmarks

## Next Steps
1. Fix code issues in order of dependency (bottom-up):
   1. Fix midi_engine.dart core functionality
   2. Implement midi_extractor_bridge.dart improvements
   3. Add UI components and integration
   4. Complete testing infrastructure

2. Focus on essential features first:
   - MIDI file parsing and export
   - Basic piano roll visualization
   - Progress reporting
   - Error handling

3. Then move to enhancement features:
   - Advanced visualization
   - Batch processing
   - Performance optimization

## Notes
- Using Spotify's Basic Pitch model for initial implementation
- Need to implement proper error handling for failed extractions
- Add progress reporting for long-running operations
- Consider adding batch processing for multiple files