# Midistems - Future Research Directions

## Introduction

This document serves as a repository for research insights, advanced concepts, and alternative technological approaches relevant to the future development and enhancement of the Midistems application. It draws primarily from the comprehensive report on "Digital Signal Processing and Audio Stem Separation in Rust" and is intended to guide long-term R&D, inspire new features, and provide context for architectural evolution.

## Advanced Rust DSP & Audio Libraries

While the current implementation plan selects specific libraries for immediate tasks, the Rust audio ecosystem is rich and evolving. The following libraries and concepts from the research report are worth noting for future consideration:

*   **`fundsp`**: A powerful library for audio processing and synthesis using an inline graph notation. Could be explored for building complex custom audio effects chains or for prototyping advanced DSP algorithms within Rust.
*   **`dsp` crate (various components)**: Offers a suite of fundamental DSP functionalities including signal generators, filters, and window functions. Useful if Midistems requires more granular DSP building blocks beyond what's offered by integrated models.
*   **Specialized FFT Libraries (`rustfft`, `realfft`, `phastft`)**: The report includes performance comparisons (e.g., `phastft` often faster and more memory-efficient). If Midistems develops features requiring direct, high-performance FFT operations (e.g., advanced spectral analysis, custom filtering), these specific benchmarks and libraries should be revisited.
*   **`basic_dsp_vector`**: Focuses on efficient DSP operations on vectors, emphasizing type safety and avoiding allocations. Could be relevant if implementing custom mathematical routines for audio processing.
*   **Other Crates from `rust.audio`**: The report mentions the `rust.audio` initiative as a hub. Periodically reviewing this resource for new and maturing libraries is advisable.

## Real-Time Audio Architecture Deep Dive

Achieving robust, ultra-low latency audio processing requires careful architectural considerations. Beyond the initial implementation of ring buffers and pre-allocation:

*   **Advanced Threading Models**: Explore more sophisticated threading models for audio processing, potentially involving dedicated threads for specific tasks (e.g., analysis, synthesis, I/O) with carefully managed priorities and synchronization (e.g., using atomic operations, more advanced `std::sync` primitives, or specialized crates if needed).
*   **Memory Pooling**: For components that might require frequent temporary buffer allocations (even if ideally avoided in the hot path), investigate memory pooling techniques to reuse memory blocks and reduce overhead compared to system allocators.
*   **Xrun (Underrun/Overflow) Handling**: Develop robust strategies for detecting and gracefully handling buffer underruns or overflows (xruns), perhaps by logging, momentarily injecting silence/repeating buffers, or providing diagnostic information to the user.
*   **Deterministic Execution**: Continuously analyze and refactor code in the real-time path to ensure deterministic execution times, minimizing jitter and unpredictable delays.

## Stem Separation - Advanced Topics

The field of audio source separation is rapidly advancing. For pushing the boundaries of quality and capability in Midistems:

*   **Phase Processing**:
    *   **Importance**: The research report strongly emphasizes that high-quality stem separation, especially for reducing artifacts and achieving natural-sounding results, critically depends on accurate phase information processing, not just amplitude.
    *   **Challenges**: Phase is complex, instrument-dependent, and traditionally hard to model correctly.
    *   **State-of-the-Art**: Models like LALAL.AI's "Phoenix" (mentioned in the report) operate in the complex number field, processing both amplitude and phase simultaneously. Exploring or developing techniques that can correctly predict or reconstruct phase for separated stems is a key R&D area.
*   **Alternative & Emerging Model Architectures**:
    *   While Demucs (and its variants via ONNX) is a strong baseline, the report mentions other promising architectures:
        *   **Advanced Transformer Models**: (e.g., SepFormer, BS-RoFormer) for capturing long-range dependencies.
        *   **Diffusion Models / Flow Matching**: (e.g., DiffSep, SGMSE, FlowSep) for potentially higher quality, though often with higher computational cost (though techniques like Flow Matching aim to reduce this).
    *   Keeping abreast of new model architectures that might offer better quality/efficiency trade-offs is crucial.
*   **Input Segment Size & Context**: The report notes that larger input segment sizes for models can improve instrument recognition and separation quality, at the cost of complexity. Researching optimal segment sizes and how models handle long-term context can yield improvements.

## Rust-Native Machine Learning

The current plan involves using ONNX for pre-trained models. For deeper integration and future custom development:

*   **`Burn` Framework**: Highlighted in the report as a next-gen deep learning framework in Rust, emphasizing performance, flexibility, and JIT compilation for optimized GPU operations. Its unique ownership-based optimization tracking is a key feature.
*   **`Candle` Framework**: Described as a "Torch Replacement in Rust," also a promising pure Rust tensor library.
*   **Potential**: These frameworks open possibilities for:
    *   Re-implementing parts of existing models in Rust for fine-grained control and optimization.
    *   Training new, custom models directly within the Rust ecosystem.
    *   Developing highly optimized inference code that leverages Rust's performance characteristics.
    *   Reducing reliance on external runtimes or FFI for ML tasks in the long term.

## Contributing Future Research

This document is intended to be a living resource. Team members are encouraged to add new findings, interesting papers, promising libraries, or innovative ideas related to audio processing, machine learning in audio, and Rust development that could benefit Midistems. When adding content, please try to summarize the key insights and their potential relevance to the project.
