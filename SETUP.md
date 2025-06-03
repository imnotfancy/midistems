# MidiStems Development Environment Setup

This document outlines the setup process for the MidiStems project, which uses Flutter for the frontend and Rust for audio processing via FFI.

## Prerequisites

- Rust (1.87.0 or later)
- Flutter (3.32.1 or later)
- ALSA development libraries (for Linux)

## Rust Setup

1. Install Rust using rustup:
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   ```

2. Verify Rust installation:
   ```bash
   rustc --version
   cargo --version
   ```

3. Install ALSA development libraries (Linux only):
   ```bash
   sudo apt-get update
   sudo apt-get install -y libasound2-dev
   ```

## Flutter Setup

1. Install Flutter by following the official guide: https://flutter.dev/docs/get-started/install

2. Verify Flutter installation:
   ```bash
   flutter --version
   flutter doctor
   ```

## Project Structure

The project is structured as follows:

- `/lib`: Flutter application code
- `/rust_core`: Rust library for audio processing
  - `/src`: Rust source code
    - `lib.rs`: Main library file with FFI exports
    - `audio_io.rs`: Audio I/O functionality
    - `dsp.rs`: Digital signal processing
    - `midi.rs`: MIDI extraction and processing

## FFI Bridge

The FFI bridge between Flutter and Rust is implemented as follows:

1. Rust side:
   - The Rust library is compiled as a cdylib (dynamic library)
   - FFI functions are exported with `#[no_mangle]` and `extern "C"`
   - Functions handle conversion between Rust and C types

2. Flutter side:
   - The `ffi` package is used to load and call the Rust library
   - The `RustAudioService` class provides a Dart interface to the Rust functions

## Building the Project

1. Build the Rust library:
   ```bash
   cd rust_core
   cargo build --release
   ```

2. Run the Flutter application:
   ```bash
   flutter run
   ```

### Cross-Platform Building

The Rust library is configured for cross-platform building with platform-specific settings:

#### Linux
- Requires ALSA development libraries (`libasound2-dev`)
- Links against `stdc++` for C++ interoperability

#### macOS
- Links against CoreAudio and AudioToolbox frameworks
- Links against `c++` for C++ interoperability

#### Windows
- Uses static CRT linking for better distribution

To build for a specific platform, you can uncomment the appropriate target in `.cargo/config.toml` or specify it on the command line:

```bash
# For Linux
cargo build --release --target x86_64-unknown-linux-gnu

# For macOS (Intel)
cargo build --release --target x86_64-apple-darwin

# For macOS (Apple Silicon)
cargo build --release --target aarch64-apple-darwin

# For Windows
cargo build --release --target x86_64-pc-windows-msvc
```

## Testing Audio System

The project includes a simple audio system test to verify that the audio subsystem is working correctly:

1. From the Flutter UI:
   - Launch the app
   - Click the "Test Audio System" button on the Audio Processing screen
   - The result will be displayed on the screen

2. Using the test_ffi project:
   ```bash
   cd test_ffi
   /workspace/run_dart.sh run bin/test_audio.dart
   ```

This test verifies that:
- The Rust audio library can be loaded
- The audio subsystem can be initialized
- Basic audio functionality is working

## Next Steps

1. Implement audio file loading in Rust
2. Implement audio playback functionality
3. Implement stem separation algorithms
4. Implement MIDI extraction
5. Create Flutter UI for audio file selection and processing
6. Implement visualization of audio and MIDI data

## Running Flutter as Non-Root User

Flutter should not be run as root for security reasons. If you're running in an environment where you're logged in as root, follow these steps:

1. Create a non-root user:
   ```bash
   useradd -m flutteruser
   passwd flutteruser
   ```

2. Change ownership of Flutter and project directories:
   ```bash
   chown -R flutteruser:flutteruser /path/to/flutter
   chown -R flutteruser:flutteruser /path/to/project
   ```

3. Use the provided scripts to run Flutter and Dart commands:
   ```bash
   # For Flutter commands
   /workspace/run_flutter.sh run
   
   # For Dart commands
   /workspace/run_dart.sh run bin/test_ffi.dart
   ```

## Troubleshooting

- If you encounter issues with ALSA on Linux, make sure the ALSA development libraries are installed
- If you encounter issues with FFI, check that the Rust library is built correctly and the path in `RustAudioService._getLibraryPath()` is correct
- If you encounter permission issues with Flutter, try running the commands without sudo/root privileges
- If you encounter pub cache permission issues, ensure the .pub-cache directory is owned by the user running Flutter:
  ```bash
  mkdir -p /home/flutteruser/.pub-cache
  chown -R flutteruser:flutteruser /home/flutteruser/.pub-cache
  ```