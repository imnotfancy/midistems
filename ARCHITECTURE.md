# Project Architecture

## Overview

This project employs a hybrid architecture to leverage the strengths of different technologies:
- **Flutter Frontend:** For the user interface and application logic.
- **Python Backend Processing:** For certain complex audio tasks where mature Python libraries are available.
- **Rust Core (FFI):** For performance-critical audio operations, low-level audio manipulation, and to explore alternative implementations of processing tasks.

## Python Components

Python scripts are currently used for specific, computation-heavy audio processing tasks. They are invoked from Dart via `Process.run()`.

### MIDI Extraction

- **Implementation:** `python/midi_extractor.py`
- **Core Library:** "Basic Pitch" (a Python library for MIDI transcription from audio).
- **Invocation:** Called from Dart via `MidiExtractorBridge.dart`, which is managed by `MidiEngine.dart`.
- **Status:** This is the current functional implementation for MIDI extraction.

### Stem Separation

- **Implementation:** `python/processor.py`
- **Core Library:** "Demucs" (a Python library for music source separation).
- **Invocation:** Called from Dart via `AudioService.dart` (located in `lib/services/audio_processing/`).
- **Status:** This is the current functional implementation for stem separation.

## Rust FFI Core (`rust_core/`)

The Rust FFI (Foreign Function Interface) core library, located in the `rust_core/` directory, serves as a native component for tasks requiring high performance, low-level system access, or where WebAssembly (Wasm) deployment might be a future consideration.

### Purpose

- To provide efficient, low-level audio processing capabilities.
- To enable the exploration and implementation of audio algorithms in Rust.
- To offer an alternative to Python for certain processing tasks, potentially reducing reliance on a Python runtime for future cross-platform builds.

### Current Capabilities

The Rust core currently provides the following FFI functions:
- **`initialize_audio_engine`:** Prepares the Rust library for use (currently a stub).
- **`test_audio_system`:** A test function to verify FFI communication and basic audio tone generation/playback (using `cpal`).
- **`load_audio_file`:** Probes an audio file using the `symphonia` crate to extract and print metadata such as sample rate, channels, and duration. It does not yet decode or store audio samples.
- **`get_last_error_message`:** An FFI function that allows Dart to retrieve the last error message set by a Rust FFI function. This is used for more detailed error reporting than just error codes.
- **`free_string`:** Allows Dart to free strings allocated by Rust and passed over FFI.
- **`cleanup_audio_engine`:** Cleans up resources used by the Rust library (currently a stub).

### Future Direction - MIDI Extraction

- **Goal:** Implement MIDI extraction capabilities directly within the Rust core.
- **Approach:** The initial focus will be on DSP-based pitch detection and transcription algorithms.
- **FFI Entry Point:** The existing `extract_midi` FFI function stub in `rust_core/src/lib.rs` is the designated entry point for this future Rust-based MIDI extraction logic.

### Future Direction - Stem Separation

- **Goal:** Implement stem separation capabilities directly within the Rust core.
- **Approach:** The strategy involves exploring options such as using a pre-trained ONNX model (e.g., a Demucs variant compatible with ONNX) in conjunction with a Rust ONNX runtime (like `tract` or `ort`).
- **FFI Entry Point:** The existing `separate_stems` FFI function stub in `rust_core/src/lib.rs` is the designated entry point for this future Rust-based stem separation logic.

## Error Handling in Python Scripts

The Python scripts (`midi_extractor.py` and `processor.py`) have been updated to provide structured JSON output to `stdout` for both successful operations and application-level errors. This allows the calling Dart code to receive more detailed error information than just relying on script exit codes.
- **Success:** `{"status": "success", "result": <data>}`
- **Error:** `{"status": "error", "error": "<error_details>"}`
The Dart bridge and service layers have been updated to parse this JSON and handle these structured responses appropriately.
