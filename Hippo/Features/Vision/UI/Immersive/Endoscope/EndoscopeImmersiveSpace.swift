//
//  EndoscopeImmersiveSpace.swift
//  Hippo
//
//  True stereo endoscope view using CompositorServices
//  Each eye receives independent texture for genuine stereoscopic 3D
//

import SwiftUI
import CompositorServices
import Metal
import simd
import os.log

/// ImmersiveSpace for true stereo endoscope streaming
/// NOTE: This is a placeholder. CompositorServices implementation is incomplete.
/// For now, use Window-based EndoscopeStreamView with VideoPlayerComponent.
@available(visionOS 2.0, *)
struct EndoscopeImmersiveSpace: View {
    @StateObject private var viewModel = EndoscopeStreamViewModel()

    var body: some View {
        Text("CompositorServices implementation coming soon")
            .padding()
            .task {
                await viewModel.connect()
            }
            .onDisappear {
                Task {
                    await viewModel.disconnect()
                }
            }
    }
}

/*
// MARK: - Stereo Compositor Renderer (DISABLED - Incomplete)

/// Renders stereo video frames to CompositorServices layer
/// Runs on dedicated render thread for optimal performance
final class StereoCompositorRenderer {

    private let logger = Logger(subsystem: "com.television.hippo", category: "StereoCompositor")
    private let layerRenderer: LayerRenderer
    private let stereoRenderer: CompositorStereoRenderer

    // Metal pipeline
    private var device: MTLDevice
    private var commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState?
    private var vertexBuffer: MTLBuffer?

    // Full-screen quad vertices (NDC)
    private let quadVertices: [Float] = [
        // Positions (x, y)    // TexCoords (u, v)
        -1,  1,                0, 0,  // Top-left
        -1, -1,                0, 1,  // Bottom-left
         1, -1,                1, 1,  // Bottom-right
         1,  1,                1, 0   // Top-right
    ]

    init(layerRenderer: LayerRenderer, stereoRenderer: CompositorStereoRenderer) {
        self.layerRenderer = layerRenderer
        self.stereoRenderer = stereoRenderer

        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Failed to create Metal device")
        }
        self.device = device

        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Failed to create command queue")
        }
        self.commandQueue = commandQueue

        setupPipeline()
        setupVertexBuffer()

        logger.info("✅ StereoCompositorRenderer initialized")
    }

    func start() {
        logger.info("🚀 Starting compositor render loop")

        // Run on background thread
        Task.detached(priority: .high) {
            await self.renderLoop()
        }
    }

    // MARK: - Render Loop

    private func renderLoop() async {
        while true {
            // Query next frame
            guard let frame = layerRenderer.queryNextFrame() else {
                // No frame available, wait briefly
                try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
                continue
            }

            // Start frame update
            frame.startUpdate()
            frame.startSubmission()

            // Render to layer drawable
            if let drawable = frame.drawable {
                renderStereo(to: drawable)
            }

            // Submit frame
            frame.endSubmission()
        }
    }

    private func renderStereo(to drawable: LayerRenderer.Drawable) {
        // Get left/right textures
        guard let leftTexture = stereoRenderer.getLeftTexture(),
              let rightTexture = stereoRenderer.getRightTexture() else {
            // No textures yet, render black
            renderBlack(to: drawable)
            return
        }

        // For now, just render left texture (proper stereo needs eye separation)
        // TODO: Implement proper stereo with eye-specific rendering
        renderTexture(leftTexture, to: drawable.colorTextures[0])
    }

    // MARK: - Metal Rendering

    private func renderTexture(_ sourceTexture: MTLTexture, to targetTexture: MTLTexture) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        // Simple blit (copy)
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else { return }

        let sourceSize = MTLSize(
            width: sourceTexture.width,
            height: sourceTexture.height,
            depth: 1
        )

        blitEncoder.copy(
            from: sourceTexture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: sourceSize,
            to: targetTexture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )

        blitEncoder.endEncoding()
        commandBuffer.commit()
    }

    private func renderBlack(to drawable: LayerRenderer.Drawable) {
        guard let colorTexture = drawable.colorTextures.first else { return }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = colorTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        renderEncoder.endEncoding()

        commandBuffer.commit()
    }

    // MARK: - Setup

    private func setupPipeline() {
        // Simple passthrough shader (if needed later)
        logger.info("📐 Pipeline setup (using blit for now)")
    }

    private func setupVertexBuffer() {
        let dataSize = quadVertices.count * MemoryLayout<Float>.stride
        vertexBuffer = device.makeBuffer(
            bytes: quadVertices,
            length: dataSize,
            options: []
        )
    }

    private enum Eye {
        case left
        case right
    }
}
*/
