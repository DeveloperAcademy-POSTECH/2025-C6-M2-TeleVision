//
//  RawStreamView.swift
//  Hippo
//
//  Stage 1: Raw stream view using Metal renderer
//  Debug mode - displays incoming video feed without processing
//

import SwiftUI
import RealityKit
import os.log

/// Stage 1: Raw Stream View (Debug Mode)
/// Displays raw video stream as-is (mono or SBS compressed)
/// Purpose: Verify video is being received before any processing
struct RawStreamView: View {
    @ObservedObject var pipeline: EndoscopeRenderPipeline

    private let logger = Logger(
        subsystem: "com.television.hippo",
        category: "RawStreamView"
    )

    // MARK: - Body

    var body: some View {
        #if os(visionOS)
        RealityView { content in
            // Setup Metal-based raw stream scene
            setupRawStreamScene(in: content)
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
                Text("Raw stream view requires visionOS")
                    .foregroundColor(.white)
            )
        #endif
    }

    // MARK: - Setup Helpers

    /// Setup Metal-based scene for raw stream display
    private func setupRawStreamScene(in content: RealityViewContent) {
        logger.info("RawStreamView: Creating RealityView")

        guard let metalRenderer = pipeline.getMetalRenderer() else {
            logger.error("Metal renderer not available")
            return
        }

        // Stage 1: Raw stream mode - dual planes to properly display SBS frames
        // Note: Incoming stream is 1920×540 (SBS format), so we need dual planes
        // to avoid compression artifacts and proper left/right separation
        metalRenderer.setupScene(in: content, mode: .dualPlanes)

        logger.info("Raw stream scene created (dual planes for SBS)")
        logger.info("  Frame size: \(Int(pipeline.currentFrameSize.width))×\(Int(pipeline.currentFrameSize.height))")
    }

    /// Log when view appears
    private func logAppear() {
        logger.info("RawStreamView appeared")
    }

    /// Log when view disappears
    private func logDisappear() {
        logger.info("RawStreamView disappeared")
    }
}

// MARK: - Preview

#Preview {
    let mockPipeline = EndoscopeRenderPipeline()

    // Configure pipeline for raw stream mode
    mockPipeline.configure(for: .rawStream)

    // Set mock frame size (Full HD mono)
    mockPipeline.currentFrameSize = CGSize(width: 1920, height: 1080)

    return RawStreamView(pipeline: mockPipeline)
}
