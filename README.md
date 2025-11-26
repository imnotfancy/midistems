# MidiStems

A Flutter application for separating audio into stems and extracting MIDI. MidiStems allows you to take any audio file and split it into separate instrument tracks while also generating MIDI data for each instrument.

![MidiStems Demo](docs/images/demo.png) *(Coming soon)*

## Features

- Audio stem separation (vocals, drums, bass, other)
- MIDI extraction with pitch and timing detection
- Multi-track playback with individual volume controls
- Piano roll visualization of MIDI data
- Cross-platform support (Windows, macOS, Linux)

## Installation

### Windows
1. Download the latest release from the [releases page](../../releases)
2. Extract the zip file
3. Run `midistems.exe`

### macOS
1. Download the latest release from the [releases page](../../releases)
2. Open the DMG file
3. Drag MidiStems to your Applications folder

### Linux
1. Download the latest release from the [releases page](../../releases)
2. Extract the tar.gz file
3. Run the executable: `./midistems`

### Building from Source

#### Prerequisites

- Flutter SDK (latest stable version)
- Rust (1.87.0 or later)
- Cargo (comes with Rust)
- Git

#### Setup Steps

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/midistems.git
   cd midistems
   ```

2. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```

3. Build the Rust library:
   ```bash
   cd rust_core
   cargo build --release
   cd ..
   ```

4. Run the app:
   ```bash
   flutter run
   ```

For more detailed setup instructions, see [SETUP.md](SETUP.md).

## Usage

1. Launch MidiStems
2. Click "Open File" to select an audio file (supports WAV, MP3, FLAC)
3. Wait for stem separation to complete
4. Use the mixer to adjust individual stem volumes
5. Click "Extract MIDI" to generate MIDI data
6. View and edit MIDI in the piano roll
7. Export stems and MIDI using the export button

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details on how to:
- Report bugs
- Suggest features
- Submit pull requests
- Set up the development environment

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Architecture

The application is built using:

- **Flutter**: For the cross-platform UI
- **Rust**: For high-performance audio processing via FFI
- **FFI (Foreign Function Interface)**: To bridge Flutter and Rust

## Project Status

- ✅ **Week 1**: Setup and Basic Infrastructure
  - Development environment setup complete
  - Rust library structure created
  - FFI bridge implemented
  - Basic Flutter UI created
  - Audio system test functionality implemented

- 🔄 **Week 2**: Audio I/O (In Progress)
  - Audio file loading
  - Audio playback
  - UI for file selection

See [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) for the full roadmap.

## Acknowledgments

- [Basic Pitch](https://github.com/spotify/basic-pitch) for MIDI extraction algorithms
- [Demucs](https://github.com/facebookresearch/demucs) for stem separation techniques
- The Flutter team for the amazing framework
- The Rust community for excellent audio processing libraries
