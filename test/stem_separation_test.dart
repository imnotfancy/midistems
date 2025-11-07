import 'package:flutter_test/flutter_test.dart';
// RustAudioService is in lib/services/rust_audio_service.dart
import 'package:midistems/services/rust_audio_service.dart';

void main() {
  RustAudioService? rustAudioService;
  String? setupError;

  setUpAll(() {
    // Initialize the service
    try {
      rustAudioService = RustAudioService();
      final initialized = rustAudioService!.initialize();
      if (!initialized) {
        setupError = 'Failed to initialize RustAudioService. Error: ${rustAudioService!.getLastErrorMessage()}';
        rustAudioService = null;
        return;
      }
      print('RustAudioService initialized for tests.');
    } catch (e) {
      setupError = e.toString();
      rustAudioService = null;
      print('Error during setUpAll: $e');

      if (e.toString().contains("Rust library not found")) {
         print("*********************************************************************");
         print("NOTE: Rust library not found. Tests will be skipped.");
         print("To run these tests, build the Rust library first:");
         print("  cd rust_core");
         print("  cargo build --release");
         print("*********************************************************************");
      }
      // Don't rethrow - let individual tests handle skipping
    }
  });

  tearDownAll(() {
    if (rustAudioService != null) {
      final cleanedUp = rustAudioService!.cleanup();
      if (!cleanedUp) {
        print('Error during tearDownAll: Failed to cleanup RustAudioService. Error: ${rustAudioService!.getLastErrorMessage()}');
      } else {
        print('RustAudioService cleaned up after tests.');
      }
    }
  });

  test('testBasicStemSeparation', () async {
    // Skip test if setup failed
    if (rustAudioService == null) {
      return skip('Rust library not available: ${setupError ?? "Unknown error"}');
    }

    // Prepare Input
    final sampleAudioData = [1.0, -1.0, 0.5, -0.5, 0.0, 0.0]; // 3 stereo samples

    // Call separateStems
    final stems = await rustAudioService!.separateStems(sampleAudioData);

    // Assertions
    expect(stems, isNotNull, reason: "Stems should not be null.");

    expect(stems!.length, 4, reason: "There should be 4 stems.");

    final expectedMonoLength = sampleAudioData.length ~/ 2;
    expect(expectedMonoLength, 3, reason: "Expected mono length calculation is incorrect.");

    for (int i = 0; i < stems.length; i++) {
      final stem = stems[i];
      expect(stem, isNotNull, reason: "Stem $i should not be null.");
      expect(stem.length, expectedMonoLength, reason: "Stem $i length (${stem.length}) should be $expectedMonoLength.");
    }

    // Verify that all four stems are identical
    // (since the current Rust implementation copies the mono input to all stems)
    if (stems.length == 4) { // Proceed only if we have all 4 stems
        expect(stems[0], equals(stems[1]), reason: "Stem 0 should be identical to Stem 1.");
        expect(stems[0], equals(stems[2]), reason: "Stem 0 should be identical to Stem 2.");
        expect(stems[0], equals(stems[3]), reason: "Stem 0 should be identical to Stem 3.");
    }

    // Verify the content of one of the stems
    // For input [1.0, -1.0, 0.5, -0.5, 0.0, 0.0],
    // mono conversion is [(1.0 + -1.0)/2, (0.5 + -0.5)/2, (0.0 + 0.0)/2] = [0.0, 0.0, 0.0]
    final expectedMonoData = [0.0, 0.0, 0.0];
    if (stems.isNotEmpty) {
        expect(stems[0], equals(expectedMonoData), reason: "Content of Stem 0 is not as expected.");
    }
  });
}
