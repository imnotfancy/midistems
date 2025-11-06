# MidiStems Documentation

This directory contains comprehensive documentation for the MidiStems project, including analysis reports, setup guides, and technical documentation.

## Directory Structure

### [Analysis](./analysis/)
Contains market research, competitive analysis, technical feasibility studies, and validation reports that form the foundation for the MidiStems project strategy.

### [Setup](./setup/)
Provides detailed guides for setting up the development environment, including FFI integration between Flutter and Rust.

## Key Documents

- [Implementation Plan](../implementation_plan.md) - Detailed project roadmap and task breakdown
- [MidiStems Validation Report](./analysis/midistems_validation_report.md) - Comprehensive analysis and strategic recommendations
- [FFI Setup Guide](./setup/ffi_setup_guide.md) - Guide for configuring Flutter-Rust integration

## Project Overview

MidiStems is a cross-platform application that combines audio stem separation with MIDI extraction capabilities. The project is being enhanced with a Rust-based audio processing core to improve performance while maintaining the Flutter-based UI for cross-platform compatibility.

### Key Features

- Multi-track audio stem separation (vocals, drums, bass, other)
- MIDI extraction with pitch and timing detection
- Multi-track playback with individual volume controls
- Piano roll visualization of MIDI data
- Cross-platform support (Windows, macOS, Linux)
- Support for multiple audio formats (WAV, MP3, FLAC)

### Technical Architecture

The project follows a hybrid architecture:
- **Frontend**: Flutter/Dart for cross-platform UI
- **Audio Core**: Rust for high-performance, low-latency audio processing
- **Integration**: Foreign Function Interface (FFI) between Dart and Rust

## Getting Started

1. Review the [Implementation Plan](../implementation_plan.md) to understand the project roadmap
2. Follow the [Setup Guides](./setup/) to configure your development environment
3. Explore the [Analysis Documents](./analysis/) for background on project decisions

## Contributing

Please refer to the [CONTRIBUTING.md](../CONTRIBUTING.md) file in the root directory for guidelines on contributing to the MidiStems project.