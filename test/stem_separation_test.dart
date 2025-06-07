import 'package:flutter_test/flutter_test.dart';
// Assuming your package name is 'my_app'. Adjust if necessary.
// If RustAudioService is in lib/services/rust_audio_service.dart
import 'package:my_app/services/rust_audio_service.dart';

void main() {
  late RustAudioService rustAudioService;

  setUpAll(() {
    // Initialize the service
    // Note: RustAudioService constructor in the provided snippet is RustAudioService._()
    // which suggests it might be a singleton obtained via a factory.
    // If RustAudioService() is the correct way to get the instance, this is fine.
    // If not, this might need adjustment based on how RustAudioService is instantiated.
    try {
      rustAudioService = RustAudioService();
      final initialized = rustAudioService.initialize();
      if (!initialized) {
        throw Exception('Failed to initialize RustAudioService. Error: ${rustAudioService.getLastErrorMessage()}');
      }
      print('RustAudioService initialized for tests.');
    } catch (e) {
      print('Error during setUpAll: $e');
      // Rethrow or handle to ensure tests don't run if setup fails catastrophically.
      // For now, printing and letting it potentially fail in tests if service is not usable.
      // A better approach might be to mark tests as skipped or fail fast.
      if (e.toString().contains("Failed to load Rust library")) {
         print("*********************************************************************");
         print("SKIPPING TESTS: Rust library not found. Ensure it's built and in the correct location.");
         print("Expected path might be relative to 'rust_core/target/release/'.");
         print("*********************************************************************");
         // This won't skip tests directly here but provides a clear message.
         // Actual skipping might need test runner configurations or specific skip calls in tests.
      }
      rethrow; // Fail fast if initialization doesn't work.
    }
  });

  tearDownAll(() {
    final cleanedUp = rustAudioService.cleanup();
    if (!cleanedUp) {
      print('Error during tearDownAll: Failed to cleanup RustAudioService. Error: ${rustAudioService.getLastErrorMessage()}');
    } else {
      print('RustAudioService cleaned up after tests.');
    }
  });

  test('testBasicStemSeparation', () async {
    // Prepare Input
    final sampleAudioData = [1.0, -1.0, 0.5, -0.5, 0.0, 0.0]; // 3 stereo samples

    // Call separateStems
    final stems = await rustAudioService.separateStems(sampleAudioData);

    // Assertions
    expect(stems, isNotNull, reason: "Stems should not be null.");
    if (stems == null) return; // Guard for null safety, though expect would fail

    expect(stems.length, 4, reason: "There should be 4 stems.");

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
