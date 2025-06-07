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

## Deep Dive: Multi-Step Stem Separation Strategies

The following sections delve into the specifics of multi-step stem separation processes, drawing from the detailed technical analysis provided in the "Adapting Multi-Step Processes for Advanced Stem Separation" report. This area is critical for pushing the boundaries of separation quality.

### Iterative Refinement Approaches
*   **Core Principle:** Progressively improve estimates by repeated application of a model or process.
*   **Training-Free Iterative Blending:**
    *   Mechanism: Iteratively apply a pre-trained model `f(.)` to an input `xt` blended from the original mixture `x0` and previous step's output `yt-1` (`xt = rt*x0 + (1-rt)*yt-1`). The blending ratio `rt` is optimized using a quality metric `R(.)`.
    *   Rationale: Exploits latent robustness learned by models during standard training with noisy mixtures.
    *   Benefits: "Free lunch" performance boost without retraining.
    *   Connection: Linked to Denoising Diffusion Bridge Models (DDBM).
    *   Mentioned Report Table: Table 1 provides a comparative overview.
*   **Diffusion Models:**
    *   Mechanism: Iteratively reverse a noise addition process.
    *   Performance: State-of-the-art, but typically requires many inference steps (50-200) and specialized training.
    *   Training-Free Application: DGMO (Diffusion-Guided Mask Optimization) uses pretrained diffusion models at test-time to refine spectrogram masks without task-specific retraining.
*   **Flow Matching Techniques:**
    *   Mechanism: Learn an ODE to transform samples from an initial to a target distribution.
    *   Efficiency: Aims for similar quality to diffusion but with fewer steps (e.g., FlowSep in 10-20 steps).
    *   Example: FLOSS (FLOw matching for Source Separation) for mixture consistency. MusicFlow (text-to-music) illustrates cascaded flow matching.
*   **Architectural Adaptations:** Training-free blending uses existing models (U-Net, Transformer) externally. Diffusion/flow models have intrinsically iterative architectures.
*   **Data Flow:** Cyclical for blending (output blended and fed back). Iterative passage for diffusion/flow.

### Cascaded Separation Systems
*   **Core Principle:** Sequential arrangement of distinct processing stages; output of one feeds the next ("divide and conquer").
*   **Architectural Examples & Data Flow:**
    *   **DJCM (Deep Joint Cascade Model):** For SVS and VPE. Separated vocal spectrogram from SVS module is direct input to VPE module. Addresses data distribution mismatch.
    *   **WA-Transformer (Window Attention-based Transformer):** Two-stage pipeline for speech/music/noise. Stage 1: coarse separation. Stage 2 (Residual Compensation Network - RCN): refines Stage 1 estimates by processing residuals.
    *   **iBeam-TFDPRNN (Iteratively Refined Multi-Channel Speech Separation):** Initial separation (TFDPRNN -> MVDR -> TFDPRNN), then iterative stages where MVDR and post-separation TFDPRNN are repeated.
    *   **MusicFlow (Illustrative):** Cascaded flow matching networks (text -> semantic features -> acoustic features).
*   **Hierarchical Separation:**
    *   Concept: Specialized cascaded separation for music, extracting stems by a defined hierarchy (e.g., instrument groups then individual instruments). Natural for music's nested structures.
    *   Simultaneous Multi-Level Separation: Models can separate submixes at multiple hierarchy levels simultaneously. Beneficial with limited fine-grained data.
    *   Expansion: Moving beyond VDB to guitar/piano, then to lead/backing vocals or drum components.
    *   Impact of Stem Extraction Order: Critical, as errors propagate. Order can simplify or complicate subsequent stages. Simultaneous learning might be optimal.

### Hybrid and Emerging Multi-Step Concepts
*   **Hybrid Waveform-Spectrogram Models:**
    *   Examples: Hybrid Demucs, HTDemucs.
    *   Rationale: Combine time-domain (good for phase/transients) and time-frequency domain (good for timbre/masking) processing.
    *   Structure: Often U-Nets for spectrograms, 1D CNNs for waveforms, potentially Transformers to bridge domains (e.g., HTDemucs cross-domain Transformer encoder).
    *   Multi-Step Potential: Could alternate domains across stages or use in cascade (e.g., spectrogram coarse separation -> waveform refinement).
*   **Training-Free Inference as an Emerging Paradigm:** Reiteration of its significance for unlocking potential in existing models without retraining.
*   **Other Blended Concepts:** Systems like iBeam-TFDPRNN blend cascaded and iterative principles.

### Architectural Choices for Multi-Step Processing
*   **Fundamental Role:** Core NN architectures (U-Nets, Transformers) are prime candidates.
*   **Adapting U-Net Architectures:**
    *   Core Structure: Encoder-decoder with skip connections, good for detailed mask estimation.
    *   Wave-U-Net: 1D convolutions for direct time-domain operation, implicitly handling phase.
    *   Multi-Source/Multi-Step Adaptations: Spectrogram-Channels U-Net (multiple output channels for different sources), iterative application of standard U-Nets, cascaded U-Nets (e.g., first separates vocals, residual fed to next).
*   **Leveraging Transformer Architectures:**
    *   Strength: Modeling long-range dependencies in music. Examples: SepFormer, BS-RoFormer.
    *   WA-Transformer: Two-stage pipeline (coarse separation, residual compensation) for multi-task separation.
    *   Perceiver Architecture: Efficient Transformer variant with latent bottleneck (e.g., "Perceparator").
    *   HTDemucs: Integrates Transformers at U-Net bottleneck for cross-domain feature fusion.
    *   CCMT (Audio-textual but illustrative): Cascaded Transformers for staged cross-modal processing.
*   **Synergistic Combinations:** Optimal may be U-Net (local detail) + Transformer (global context). Example: Transformer encoder for global context, U-Net decoders for specific stems.

### Managing Data Flow and Ensuring Consistency
*   **Importance:** Crucial to prevent error accumulation and ensure coherent output.
*   **Coherent Information Transfer:**
    *   Iterative Refinement: Cyclical flow (previous output blended with original mixture).
    *   Cascaded Systems: Direct output-to-input flow (e.g., DJCM, WA-Transformer).
    *   Residual Passing: Subsequent stages focus on correcting errors or separating from the residual.
*   **Strategies for Maintaining Consistency:**
    *   Mixture Consistency: Sum of stems reconstructs original mixture (e.g., FLOSS, Wave-U-Net difference output layer).
    *   Hierarchical Consistency: Parent node in hierarchy consistent with sum of children.
    *   CrossSDC (Continual Audio-Visual Separation): Distillation to maintain consistency with prior knowledge (conceptually relevant).
    *   Shared Representations/Encoders: Promotes consistent features before specialized decoders.
    *   Explicit Data Flow Modeling (e.g., MHC): For verifiable complex pipelines.

### Advanced Phase Processing in Multi-Step Systems
*   **Criticality:** Accurate phase is vital for high-fidelity audio.
*   **Limitations of Mixture Phase:** Using mixture phase is suboptimal ("noisy").
*   **Iterative Phase Estimation:**
    *   Griffin-Lim Algorithm (GLA): Iterative STFT/iSTFT to make phase consistent with magnitude. Differentiable for NN integration.
    *   MISI (Multiple Input Spectrogram Inversion): GLA variant for multi-source, constrains sum to mixture.
    *   Sinusoidal-based Partial Phase Reconstruction: Uses sinusoidal model for confidence domain, improving MISI.
*   **Classification-based Phase Estimation (PhaseNet):** Discretizes phase into classes, network predicts distribution. Overcomes phase wrapping issues.
*   **End-to-End Learned Phase:** Waveform models (Wave-U-Net, Demucs) implicitly learn phase.
*   **Integrating Phase Processing in Multi-Step/Cascaded Pipelines:**
    *   Dedicated Phase Optimization Stage: Post-magnitude estimation (e.g., MOP then POP in speech enhancement).
    *   Iterative Phase Refinement within Loop: GLA/MISI applied after each magnitude update.
    *   STFT-Domain Cascaded Processing: Each stage handles phase.
*   Mentioned Report Table: Table 3 provides overview of these techniques.

### Artifact Reduction in Multi-Step Separation
*   **Challenge:** Multi-step can amplify artifacts ("musical noise," distortions).
*   **Artifact-Aware Training Objectives:**
    *   SI-SAR (Scale-Invariant Signal-to-Artifact Ratio): Loss component to penalize artifact energy.
*   **Perceptual Loss Functions:**
    *   Goal: Guide model to perceptually pleasing outputs, indirectly minimizing artifacts.
    *   Method: Use features from pre-trained networks or psychoacoustic models (e.g., MP3-emulating differentiable function).
    *   Relevance: Improves naturalness in cascaded models for CT denoising, speech generation.
*   **Iterative Refinement and Blending:** Continuous re-evaluation and blending might smooth artifacts.
*   **Dedicated Artifact Reduction Stages/Techniques:**
    *   Observation Adding (OA): Add small % of original noisy input back to separated signal.
    *   Adaptive Phase Alignment (Conceptual): Ensuring phase consistency.
    *   General Signal Processing: Artifact template subtraction, specialized filtering.
*   **Consistency Constraints Between Stages:** Smooth transitions prevent discontinuity artifacts.
*   Mentioned Report Table: Table 4 provides overview of these strategies.

### Optimizing Computational Cost versus Separation Quality (SDR)
*   **Central Trade-off:** Multi-step usually means higher SDR but higher cost.
*   **SDR Improvements vs. Number of Steps/Stages:** Often diminishing returns.
        *   Training-Free Iterative Methods: Significant gains in initial few iterations.
        *   Diffusion/Flow Models: Quality improves with steps, directly impacting cost.
        *   MUSDB18 Benchmark: High-performing models often multi-step/hybrid (e.g., Sparse HT Demucs, BS-RoFormer). Table 2 gives examples.
*   **Strategies for Efficient Multi-Step Inference:**
    *   Reduced Step Counts for Diffusion/Flow: E.g., progressive distillation.
    *   Optimizing Iterations (Training-Free): Tune iteration count `T`, early exiting.
    *   Model Pruning and Quantization.
    *   Efficient Architectures (e.g., Perceiver).
    *   Adaptive Computation: Dynamically adjust steps based on input/target quality.
*   **SDR vs. Perception:** High SDR doesn't always mean good perceptual quality. Complement with perceptual evaluation.

### Incorporating Large Observation Segments and Long-Range Temporal Context
*   **Importance for Music:** Capturing structures, motifs, dependencies over time for coherence.
*   **Transformer Architectures:** Well-suited due to self-attention for long-range dependencies.
*   **U-Net Adaptations for Larger Inputs:**
    *   Tiling Strategy: Process overlapping segments, stitch results.
    *   Direct Processing of Longer Segments (if resources permit).
*   **Iterative Refinement over Large Segments:** Builds consistent separation over wider window ("contextual snowballing").
*   **Hierarchical Processing:** Implicitly handles longer contexts at higher hierarchy levels.
*   **Receptive Field Considerations:** Dilated convolutions (U-Nets, Demucs), global self-attention (Transformers). Multi-step can further expand effective temporal window.

### Advanced Topics and Future Directions in Multi-Step Separation
*   **The Evolving Role of Training-Free Multi-Step Methods:**
    *   "Free Lunch" Scaling: Performance gains comparable to larger models/datasets by exploiting learned robustness.
    *   Theoretical Links: Connection to Denoising Diffusion Bridge Models (DDBM).
    *   Oracle Metric Bottleneck: Practical utility limited by reliance on intrusive metrics (requiring ground truth) to guide refinement. Developing robust, non-intrusive perceptual metrics is key.
    *   Future: Better blending strategies, understanding diminishing returns.
*   **Beyond SDR: Holistic Evaluation of Multi-Step Separation Quality:**
    *   Limitations of SDR: Poor correlation with human perception of artifacts and naturalness.
    *   Need for Perceptual Metrics: E.g., PESQ, STOI (speech), DNSMOS (music), learned perceptual metrics.
    *   Task-Specific and Artifact-Specific Evaluation: Subjective listening tests for downstream usability, metrics like SI-SAR for artifact quantification.
*   **Emerging Research and Untapped Potential:**
    *   Zero-Shot Separation with Generative Models: Repurposing pretrained generative models (e.g., audio diffusion models) for separation without task-specific training (e.g., DGMO framework). Leverages rich priors from large, diverse datasets.
    *   Continual Learning for Separation: Models that incrementally learn new sound classes without forgetting old ones (e.g., ContAV-Sep for audio-visual).
    *   Hierarchical Separation Refinements: Learning hierarchical structures from data, adapting to genre, more effective information sharing across levels.
    *   Advanced Data Flow Control: More explicit, potentially learnable control over information flow in complex pipelines.
    *   Exploiting Cross-Stem Dependencies: Explicitly modeling musical dependencies between stems across separation stages.
*   **Recommendations and Conclusion from the Report:**
    *   Guidance: Choice of multi-step paradigm depends on target stems, quality vs. cost, data availability.
    *   Best Practices: Clear stage/iteration roles, robust data flow, hybrid domain consideration, long-range context. For training: advanced losses, staged training, data augmentation. For deployment: inference optimization, metric selection for training-free, thorough evaluation.
    *   Key Takeaways: Multi-step enhances quality. Critical considerations: architecture, data flow, phase, artifacts, cost. Long-range context is vital.
    *   Outlook: More efficient architectures, better perceptual metrics, maturation of training-free methods (solving oracle bottleneck), zero-shot separation, continual learning, refined hierarchical separation. The "trilemma": quality, cost, and absence of artifacts.
