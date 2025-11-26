# MidiStems Setup Guides

This directory contains setup guides and documentation for configuring the development environment for the MidiStems project.

## Available Guides

### 1. [FFI Environment and Project Setup Guide](./ffi_setup_guide.md)
A comprehensive guide for setting up the Foreign Function Interface (FFI) between Dart/Flutter and Rust. This guide is essential for developers working on the integration of the Rust audio core with the Flutter UI.

## Development Environment Requirements

The MidiStems project requires the following development tools:

1. **Flutter SDK** - For cross-platform UI development
2. **Dart SDK** - Included with Flutter
3. **Rust** - For audio processing core (version 1.75.0 or later recommended)
4. **Platform-specific build tools**:
   - Windows: Visual Studio with C++ development tools
   - macOS: Xcode and Command Line Tools
   - Linux: build-essential, clang, and other development packages

## Getting Started

1. Follow the [FFI Environment and Project Setup Guide](./ffi_setup_guide.md) to set up your development environment
2. Refer to the [Implementation Plan](../../implementation_plan.md) for the project roadmap and development tasks
3. Check the [Analysis Documentation](../analysis/README.md) for background information on the project

## Troubleshooting

If you encounter issues during setup:

1. Ensure all required dependencies are installed and properly configured
2. Check that environment variables (PATH, etc.) are correctly set
3. Verify that the Rust and Flutter versions are compatible with the project requirements
4. Consult the platform-specific sections in the guides for OS-specific considerations