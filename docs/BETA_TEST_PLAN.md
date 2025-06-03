# MidiStems - Beta Test Plan (Post-Rust FFI Integration)

## 1. Introduction

This document outlines the plan for beta testing the MidiStems application after the initial integration of the Rust FFI layer for handling Python-based MIDI extraction and stem separation.

**Important Prerequisite:** This beta test can only commence once the development environment is fully configured as per `docs/FFI_ENVIRONMENT_SETUP.MD`, allowing the MidiStems Flutter application with its Rust dynamic library component to be successfully built and packaged for target platforms (Windows, macOS, Linux).

## 2. Beta Program Goals

*   **Primary Goal: Stability & Functionality Verification:**
    *   Confirm that the FFI bridge between Dart (Flutter) and Rust is stable across different user setups.
    *   Verify that the core functionalities (MIDI extraction and stem separation, now routed through Rust to Python) work reliably and produce correct outputs.
    *   Identify and document any crashes, hangs, or unexpected behavior related to the FFI calls or the underlying Python script execution.
*   **Secondary Goal: Perceived Performance & User Experience:**
    *   Gather qualitative feedback on whether users perceive any difference in performance (speed, responsiveness) for MIDI extraction and stem separation tasks.
    *   Assess the overall user experience with these core features now that they involve the Rust FFI layer.
*   **Tertiary Goal: Installation & Setup:**
    *   Collect feedback on the ease or difficulty of installing and running the beta application (which now includes a bundled Rust component).
*   **Bug Identification:** Uncover and document bugs or issues not found during internal development.

## 3. Target Beta Testers

*   **Profile 1: Existing/Previous Users (if any):**
    *   Users familiar with any previous versions of MidiStems (if applicable).
    *   Valuable for comparing perceived performance and identifying regressions.
*   **Profile 2: Semi-Professional Music Producers:**
    *   Individuals who regularly work with DAWs, MIDI, and audio stems.
    *   Can provide feedback on how MidiStems fits into their workflow and if the quality/performance meets their standards.
    *   Target users identified in `docs/analysis/market_demand_analysis.md`.
*   **Profile 3: Content Creators / Hobbyist Musicians:**
    *   Users who need quick stem separation or MIDI generation for projects (e.g., video backing tracks, learning songs).
    *   Can provide feedback on ease of use and general utility.
*   **Technical Requirements for Testers:**
    *   Comfortable installing desktop applications on Windows, macOS, or Linux.
    *   Willing to provide detailed bug reports, including steps to reproduce.
    *   Optionally, able to provide application logs if significant issues occur.

## 4. Beta Test Scope

*   **In Scope:**
    *   Installation and launch of the MidiStems application.
    *   Core feature: MIDI extraction from an audio file (using the Rust FFI -> Python path).
    *   Core feature: Stem separation from an audio file (using the Rust FFI -> Python path).
    *   UI interaction related to initiating these processes and viewing/using their results.
    *   Basic playback or handling of the generated MIDI and stem files within the application (as currently implemented).
    *   Overall application stability during these operations.
*   **Out of Scope (for this specific beta, unless explicitly included later):**
    *   Advanced audio editing features beyond basic stem/MIDI generation and playback.
    *   Stress testing with exceptionally large files or a high volume of simultaneous operations (unless specifically requested for certain testers).
    *   Features not directly related to the Rust FFI integration (unless they are broken by it).

## 5. Beta Test Duration

*   **Proposed Duration:** 2-4 weeks.
*   This allows enough time for users to install, test various audio files, and provide thoughtful feedback.

## 6. Beta Distribution

*   **Method:** Direct distribution of application binaries (e.g., `.exe` for Windows, `.dmg` or `.app` for macOS, `.deb`/`.rpm`/AppImage or archive for Linux).
*   A private download link (e.g., via Google Drive, Dropbox, or a temporary private GitHub Release) will be provided to selected testers.
*   Clear installation instructions, including any notes related to the FFI component or potential OS-specific permissions, should be provided.

## 7. Feedback Collection Mechanisms

*   **Primary: Structured Feedback Form:**
    *   Use a tool like Google Forms, Typeform, or a simple structured document.
    *   Sections for:
        *   Tester Information (OS, system specs - optional but helpful).
        *   Installation Experience (Rating, Comments).
        *   MIDI Extraction (Success/Failure, Perceived Speed, Output Quality, Bugs).
        *   Stem Separation (Success/Failure, Perceived Speed, Output Quality, Bugs).
        *   Overall Stability & Performance (Crashes, Responsiveness).
        *   Suggestions for Improvement.
        *   Overall Satisfaction.
*   **Secondary: Bug Reporting Channel:**
    *   Dedicated email address (e.g., `midistems-beta-feedback@example.com`).
    *   Or, a specific GitHub Issues template if testers are comfortable with GitHub.
    *   Encourage detailed reports: steps to reproduce, expected vs. actual results, screenshots, and (if possible) application logs.
*   **Optional: Communication Channel:**
    *   A private Discord channel or Slack channel for more immediate interaction, Q&A, and community building among beta testers.

## 8. Key Areas for Feedback / Test Cases

Testers should be encouraged to try:

*   **MIDI Extraction:**
    *   Various audio file types (WAV, MP3, FLAC, OGG).
    *   Short and long audio files.
    *   Files with solo instruments and polyphonic music.
    *   Verify if the generated MIDI file path is correct and the file is created.
    *   (If MIDI parsing is implemented in UI) Verify basic correctness of MIDI data.
*   **Stem Separation:**
    *   Various audio file types.
    *   Different musical genres.
    *   Verify if the output directory is created and stem files (vocals.wav, bass.wav, etc.) are present.
    *   (If stem playback is robust) Verify basic quality of separated stems.
*   **Error Handling:**
    *   Try processing invalid or corrupted audio files.
    *   Note any error messages displayed by the application.
*   **Usability:**
    *   How intuitive is the process for MIDI extraction?
    *   How intuitive is the process for stem separation?
    *   Is the feedback from the application (loading states, error messages) clear?
*   **Performance (Qualitative):**
    *   Does MIDI extraction feel reasonably fast?
    *   Does stem separation feel reasonably fast?
    *   Is the UI responsive during these operations (recognizing that full Isolate optimization may not be in place yet)?

## 9. Beta Test Communication

*   **Initial Email:** Welcome, link to download, link to feedback form, instructions, support contact.
*   **Mid-Beta Reminder:** Encourage further testing and feedback submission.
*   **End of Beta Email:** Thank participants, final call for feedback, information on next steps.

## 10. Post-Beta Analysis

*   Collect all feedback from forms, emails, and communication channels.
*   Categorize feedback (bugs, feature requests, performance issues, usability comments).
*   Prioritize bugs based on severity.
*   Analyze feedback to inform the next development iteration (e.g., which FFI path to optimize first, critical UI fixes).
*   Share a summary of findings and planned actions with beta testers (optional, but good for engagement).

---

This plan provides a framework. It should be adapted based on the actual state of the application when it's ready for external testing.
