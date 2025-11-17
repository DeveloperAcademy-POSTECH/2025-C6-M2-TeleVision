//
//  SplitSBSView.swift
//  Hippo
//
//  Stage 2: Split SBS view using Metal renderer
//  Debug mode - displays left/right eye separation for quality check
//

import SwiftUI
import RealityKit
import os.log

/// Stage 2: Split SBS View (Debug Mode)
/// Displays SBS video split into left/right for debugging
/// Purpose: Verify SBS splitting logic and per-eye quality
struct SplitSBSView: View {
    @ObservedObject var pipeline: EndoscopeRenderPipeline

    private let logger = Logger(
        subsystem: "com.television.hippo",
        category: "SplitSBSView"
    )

    // MARK: - Body

    var body: some View {
        #if os(visionOS)
        RealityView { content in
            // Setup Metal-based split SBS scene
            setupSplitViewScene(in: content)
        }
        .frame(depth: 0)
        .onAppear {
            logAppear()
        }
        .onDisappear {
            logDisappear()
        }
        #else
        Color.black
            .overlay(
                Text("Split SBS view requires visionOS")
                    .foregroundColor(.white)
            )
        #endif
    }

    // MARK: - Setup Helpers

    /// Setup Metal-based scene for split SBS display
    private func setupSplitViewScene(in content: RealityViewContent) {
        logger.info("SplitSBSView: Creating RealityView")

        guard let metalRenderer = pipeline.getMetalRenderer() else {
            logger.error("Metal renderer not available for split view")
            return
        }

        // Stage 2: Split SBS mode - dual planes for left/right eye separation debugging
        // Metal renderer is explicitly configured with .dualPlanes scene mode
        metalRenderer.setupScene(in: content, mode: .dualPlanes)

        logger.info("Split SBS scene created (dual planes)")
        logger.info("  Frame size: \(Int(pipeline.currentFrameSize.width))×\(Int(pipeline.currentFrameSize.height))")
    }

    /// Log when view appears
    private func logAppear() {
        logger.info("SplitSBSView appeared")
    }

    /// Log when view disappears
    private func logDisappear() {
        logger.info("SplitSBSView disappeared")
    }
}

// MARK: - Preview

#Preview {
    let mockPipeline = EndoscopeRenderPipeline()

    // Configure pipeline for split SBS mode
    mockPipeline.configure(for: .splitSBS)

    // Set mock frame size (Full SBS: 3840×1080)
    mockPipeline.currentFrameSize = CGSize(width: 3840, height: 1080)

    return SplitSBSView(pipeline: mockPipeline)
}
