//
//  CompositorStereoRenderer.swift
//  Hippo
//
//  CompositorServices-based true stereo renderer for Vision Pro
//  Renders left/right eye independently using Metal
//

import Foundation
import CompositorServices
import Metal
import MetalKit
import CoreVideo
import simd
import os.log
import Combine

/// True stereo renderer using CompositorServices
/// Each eye receives independent texture for genuine stereoscopic 3D
@MainActor
@available(visionOS 2.0, *)
public final class CompositorStereoRenderer: ObservableObject {

    // MARK: Published Properties

    @Published public var isReady: Bool = false

    // MARK: Private Properties

    private let logger = Logger(subsystem: "com.television.hippo", category: "CompositorStereo")

    // Metal components
    private var metalDevice: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var textureCache: CVMetalTextureCache?

    // Current frame textures (thread-safe access via queue)
    private let textureQueue = DispatchQueue(label: "com.television.hippo.compositor.textures")
    private var _leftTexture: MTLTexture?
    private var _rightTexture: MTLTexture?

    // Frame counter
    private var frameCount: UInt64 = 0

    // MARK: Initialization

    public init() {
        setupMetal()
        logger.info("✅ CompositorStereoRenderer initialized")
    }

    // MARK: - Public Methods

    /// Update frame with new SBS pixel buffer
    /// Splits SBS into left/right textures for independent eye rendering
    public func updateFrame(_ pixelBuffer: CVPixelBuffer) {
        guard isReady else {
            logger.warning("⚠️ Renderer not ready")
            return
        }

        frameCount += 1

        // Skip every other frame for performance (30fps → 15fps)
        if frameCount % 2 == 0 {
            return
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        // Detect SBS vs Mono
        let aspectRatio = Float(width) / Float(height)
        let isSBS = aspectRatio > 2.5  // > 2.5:1 is SBS

        guard isSBS else {
            logger.warning("⚠️ Mono mode not supported in CompositorServices renderer")
            return
        }

        // Split SBS into left/right
        let halfWidth = width / 2

        guard let sourceTexture = createMetalTexture(from: pixelBuffer) else {
            logger.warning("⚠️ Failed to create source texture")
            return
        }

        // Create destination textures
        guard let leftTex = makeRGBA8Texture(width: halfWidth, height: height),
              let rightTex = makeRGBA8Texture(width: halfWidth, height: height) else {
            logger.error("❌ Failed to allocate textures")
            return
        }

        // Blit split regions
        guard copyRegion(from: sourceTexture, sourceOriginX: 0, width: halfWidth, height: height, to: leftTex),
              copyRegion(from: sourceTexture, sourceOriginX: halfWidth, width: halfWidth, height: height, to: rightTex) else {
            logger.error("❌ Failed to split SBS")
            return
        }

        // Update textures atomically
        textureQueue.sync {
            self._leftTexture = leftTex
            self._rightTexture = rightTex
        }

        if frameCount <= 5 {
            logger.info("🎬 Frame #\(self.frameCount): SBS \(width)×\(height) split to L/R \(halfWidth)×\(height)")
        }
    }

    /// Get left eye texture (thread-safe)
    public func getLeftTexture() -> MTLTexture? {
        textureQueue.sync { _leftTexture }
    }

    /// Get right eye texture (thread-safe)
    public func getRightTexture() -> MTLTexture? {
        textureQueue.sync { _rightTexture }
    }

    // MARK: - Private Methods

    private func setupMetal() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            logger.error("❌ Failed to create Metal device")
            return
        }

        self.metalDevice = device

        var cache: CVMetalTextureCache?
        let result = CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            nil,
            device,
            nil,
            &cache
        )

        guard result == kCVReturnSuccess, let cache = cache else {
            logger.error("❌ Failed to create texture cache")
            return
        }

        self.textureCache = cache
        self.commandQueue = device.makeCommandQueue()

        isReady = true
        logger.info("✅ Metal setup complete for CompositorServices")
    }

    private func createMetalTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        guard let cache = textureCache else { return nil }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        var cvTexture: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            cache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTexture
        )

        guard result == kCVReturnSuccess,
              let cvTexture = cvTexture,
              let texture = CVMetalTextureGetTexture(cvTexture) else {
            return nil
        }

        return texture
    }

    private func makeRGBA8Texture(width: Int, height: Int) -> MTLTexture? {
        guard let device = metalDevice else { return nil }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]

        return device.makeTexture(descriptor: descriptor)
    }

    private func copyRegion(from src: MTLTexture, sourceOriginX: Int, width: Int, height: Int, to dst: MTLTexture) -> Bool {
        guard let commandBuffer = commandQueue?.makeCommandBuffer(),
              let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            return false
        }

        let region = MTLRegion(
            origin: MTLOrigin(x: sourceOriginX, y: 0, z: 0),
            size: MTLSize(width: width, height: height, depth: 1)
        )

        blitEncoder.copy(
            from: src,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: region.origin,
            sourceSize: region.size,
            to: dst,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )

        blitEncoder.endEncoding()
        commandBuffer.commit()
        return true
    }
}
