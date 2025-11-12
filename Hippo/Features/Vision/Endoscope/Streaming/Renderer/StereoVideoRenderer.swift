//
//  StereoVideoRenderer.swift
//  Hippo
//
//  RealityKit-based stereo video renderer for Vision Pro
//  Renders variable-size SBS (Full-SBS, Half-SBS, or any WxH where left/right are side-by-side)
//

import RealityKit
import SwiftUI
import CoreVideo
import Metal
import MetalKit
import os.log
import Combine

// MARK: - Eye Enum

/// Specifies which eye a plane is for
private enum Eye {
    case left
    case right
}

// MARK: - Stereo Video Renderer

/// Renders SBS video to RealityKit stereo planes
@MainActor
public final class StereoVideoRenderer: ObservableObject {

    // MARK: Published Properties

    @Published public var isReady: Bool = false

    // MARK: Private Properties

    private let logger = Logger(subsystem: "com.television.hippo", category: "StereoRenderer")

    // Renderer lifecycle tracking (nonisolated to allow access from deinit)
    private let rendererID = UUID()
    private nonisolated(unsafe) static var activeRendererID: UUID?
    private static let rendererLock = NSLock()

    // RealityKit components
    private var leftPlaneEntity: ModelEntity?
    private var rightPlaneEntity: ModelEntity?

    // Metal components
    private var metalDevice: MTLDevice?
    private var textureCache: CVMetalTextureCache?
    private var commandQueue: MTLCommandQueue?

    // Video configuration - original working settings
    private let planeWidth: Float = 0.4     // meters (original size)
    private let planeHeight: Float = 0.225  // meters (16:9 aspect ratio)
    private let planeDistance: Float = 1.5  // meters from user (original)
    private let eyeSeparation: Float = 0.063 // 63mm IPD

    // Cached textures to avoid reallocation every frame
    private var cachedLeftTexture: MTLTexture?
    private var cachedRightTexture: MTLTexture?
    private var cachedSourceSize: (w: Int, h: Int)?

    // Frame skip counter for performance optimization
    private var frameCounter: UInt64 = 0

    // MARK: Initialization

    public init() {
        setupMetal()
        logger.info("🔧 Renderer created: \(self.rendererID) (not active yet)")
    }

    deinit {
        // Unregister this renderer
        Self.rendererLock.lock()
        defer { Self.rendererLock.unlock() }

        if Self.activeRendererID == rendererID {
            Self.activeRendererID = nil
            logger.info("🗑️ Active renderer destroyed: \(self.rendererID)")
        } else {
            logger.info("🗑️ Inactive renderer destroyed: \(self.rendererID)")
        }
    }

    // MARK: - Lifecycle Management

    /// Activate this renderer (make it the active renderer for receiving frames)
    public func activate() {
        Self.rendererLock.lock()
        defer { Self.rendererLock.unlock() }

        if let existingID = Self.activeRendererID, existingID != rendererID {
            logger.warning("⚠️ Activating renderer \(self.rendererID), deactivating \(existingID)")
        }

        Self.activeRendererID = rendererID
        logger.info("✅ Renderer activated: \(self.rendererID)")
    }

    /// Deactivate this renderer (stop receiving frames)
    public func deactivate() {
        Self.rendererLock.lock()
        defer { Self.rendererLock.unlock() }

        if Self.activeRendererID == rendererID {
            Self.activeRendererID = nil
            logger.info("🛑 Renderer deactivated: \(self.rendererID)")
        }
    }

    // MARK: - Public Methods

    /// Setup stereo planes in RealityKit scene
    public func setupScene(in content: RealityViewContent) {
        // For window-based RealityView, add planes directly without anchor
        // Create left eye plane positioned for left eye viewing
        let leftPlane = createVideoPlane(forEye: .left)
        // Don't override position - it's already set in createVideoPlane
        leftPlaneEntity = leftPlane
        content.add(leftPlane)
        logger.info("👁️ Left eye plane created and added to content at position: \(leftPlane.position)")

        // Create right eye plane positioned for right eye viewing
        let rightPlane = createVideoPlane(forEye: .right)
        // Don't override position - it's already set in createVideoPlane
        rightPlaneEntity = rightPlane
        content.add(rightPlane)
        logger.info("👁️ Right eye plane created and added to content at position: \(rightPlane.position)")

        isReady = true

        // Activate this renderer when scene is set up
        activate()

        logger.info("✅ Stereo scene ready - planes added directly to RealityView content")
    }

    /// Update video texture with new frame (SBS or Mono)
    /// Auto-detects mode based on aspect ratio:
    /// - ~16:9 (1.78) → Mono
    /// - ~32:9 (3.56) → SBS (Side-by-Side)
    public func updateFrame(_ pixelBuffer: CVPixelBuffer) {
        // Performance optimization: Render every other frame (30fps) to reduce CPU/memory load
        // This reduces the expensive CPU readback in TextureResource creation
        // while maintaining acceptable smoothness
        frameCounter += 1
        if frameCounter % 2 != 0 {
            return  // Skip every other frame (render at ~30fps instead of 60fps)
        }

        // Log only occasionally to avoid spam
        if frameCounter <= 10 || frameCounter % 120 == 0 {
            logger.info("🔍 updateFrame called - isReady: \(self.isReady), leftPlane: \(self.leftPlaneEntity != nil), rightPlane: \(self.rightPlaneEntity != nil)")
        }

        guard isReady else {
            logger.warning("⚠️ Renderer not ready")
            return
        }

        // Check if this is the active renderer
        Self.rendererLock.lock()
        let currentActiveID = Self.activeRendererID
        Self.rendererLock.unlock()

        guard currentActiveID == rendererID else {
            logger.warning("⚠️ Frame sent to inactive renderer \(self.rendererID), active is \(currentActiveID?.description ?? "none")")
            return
        }

        // Create Metal texture from pixel buffer
        guard let sourceTexture = createMetalTexture(from: pixelBuffer) else {
            logger.warning("⚠️ Failed to create Metal texture from pixel buffer")
            return
        }

        let srcW = sourceTexture.width
        let srcH = sourceTexture.height

        // Auto-detect Mono vs SBS based on aspect ratio
        let aspectRatio = Float(srcW) / Float(srcH)
        let isMono = aspectRatio < 2.5  // < 2.5:1 → Mono (16:9 = 1.78), >= 2.5:1 → SBS (32:9 = 3.56)

        if isMono {
            if frameCounter <= 10 {
                logger.info("📺 Mono mode detected: \(srcW)×\(srcH) (aspect: \(String(format: "%.2f", aspectRatio)))")
            }
            updateMonoFrame(sourceTexture: sourceTexture, width: srcW, height: srcH)
        } else {
            if frameCounter <= 10 {
                logger.info("👁️👁️ SBS mode detected: \(srcW)×\(srcH) (aspect: \(String(format: "%.2f", aspectRatio)))")
            }
            updateSBSFrame(sourceTexture: sourceTexture, width: srcW, height: srcH)
        }
    }

    /// Update frame in Mono mode (single image, preserve aspect ratio)
    private func updateMonoFrame(sourceTexture: MTLTexture, width: Int, height: Int) {
        // Allocate or reuse mono texture
        if cachedSourceSize?.w != width || cachedSourceSize?.h != height {
            cachedLeftTexture = makeRGBA8Texture(width: width, height: height)
            cachedSourceSize = (width, height)
            logger.info("📐 Mono texture allocated: \(width)×\(height)")
        }

        guard let monoTexture = cachedLeftTexture else {
            logger.error("❌ Failed to allocate mono texture")
            return
        }

        // Copy entire frame to mono texture
        guard copyRegion(
            from: sourceTexture,
            sourceOriginX: 0,
            width: width,
            height: height,
            to: monoTexture
        ) else {
            logger.error("❌ Failed to copy mono frame")
            return
        }

        // Adjust plane aspect ratio to match source (aspectFit)
        // Keep height fixed, adjust width to preserve aspect ratio
        let sourceAspect = Float(width) / Float(height)
        let targetHeight = planeHeight  // Fixed height (0.225m)
        let targetWidth = targetHeight * sourceAspect  // Width adjusted for aspect ratio

        // Scale plane to match aspect ratio (scale based on default plane size)
        let widthScale = targetWidth / planeWidth
        leftPlaneEntity?.scale = SIMD3(x: widthScale, y: 1.0, z: 1.0)

        logger.debug("📐 Mono plane scaled: aspect=\(String(format: "%.2f", sourceAspect)), scale=\(String(format: "%.2f", widthScale))x")

        // Update left plane with mono texture (right plane is hidden/unused)
        updatePlaneMaterial(leftPlaneEntity, with: monoTexture)
        updatePlaneMaterial(rightPlaneEntity, with: nil)  // Clear right plane

        logger.debug("🎬 Mono frame updated: \(width)×\(height)")
    }

    /// Update frame in SBS mode (split left/right)
    private func updateSBSFrame(sourceTexture: MTLTexture, width: Int, height: Int) {
        // Validate SBS: width must be divisible by 2
        guard width >= 2, width % 2 == 0, height >= 1 else {
            logger.warning("⚠️ Invalid SBS size: \(width)×\(height). Expected width divisible by 2.")
            return
        }

        let halfWidth = width / 2

        // Allocate or reuse left/right destination textures
        if cachedSourceSize?.w != width || cachedSourceSize?.h != height {
            cachedLeftTexture = makeRGBA8Texture(width: halfWidth, height: height)
            cachedRightTexture = makeRGBA8Texture(width: halfWidth, height: height)
            cachedSourceSize = (width, height)
            logger.info("📐 SBS textures updated: \(halfWidth)×\(height)")
        }

        guard let leftTexture = cachedLeftTexture,
              let rightTexture = cachedRightTexture else {
            logger.error("❌ Failed to allocate destination textures for split")
            return
        }

        // Reset plane scale to default for SBS mode
        leftPlaneEntity?.scale = SIMD3(x: 1.0, y: 1.0, z: 1.0)
        rightPlaneEntity?.scale = SIMD3(x: 1.0, y: 1.0, z: 1.0)

        // Split SBS texture into left/right via blit (GPU copy, no CPU readback)
        guard copyRegion(
            from: sourceTexture,
            sourceOriginX: 0,
            width: halfWidth,
            height: height,
            to: leftTexture
        ), copyRegion(
            from: sourceTexture,
            sourceOriginX: halfWidth,
            width: halfWidth,
            height: height,
            to: rightTexture
        ) else {
            logger.error("❌ Failed to split SBS texture via blit")
            return
        }

        // Update plane materials
        updatePlaneMaterial(leftPlaneEntity, with: leftTexture)
        updatePlaneMaterial(rightPlaneEntity, with: rightTexture)

        logger.debug("🎬 SBS frame updated: \(width)×\(height) (half=\(halfWidth)×\(height))")
    }

    // MARK: - Private Methods

    /// Setup Metal device and texture cache
    private func setupMetal() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            logger.error("❌ Failed to create Metal device")
            return
        }

        self.metalDevice = device

        var textureCache: CVMetalTextureCache?
        let result = CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            nil,
            device,
            nil,
            &textureCache
        )

        guard result == kCVReturnSuccess, let cache = textureCache else {
            logger.error("❌ Failed to create Metal texture cache")
            return
        }

        self.textureCache = cache

        // Create command queue
        self.commandQueue = device.makeCommandQueue()

        logger.info("✅ Metal setup complete")
    }

    /// Create video plane entity for specific eye
    /// Positions left/right planes using IPD (Inter-Pupillary Distance) separation
    /// for proper stereo depth perception
    private func createVideoPlane(forEye eye: Eye) -> ModelEntity {
        // Create plane mesh
        let mesh = MeshResource.generatePlane(
            width: planeWidth,
            height: planeHeight
        )

        // Create material with bright color for debugging
        var material = UnlitMaterial()
        // Start with green to verify plane is visible (bright green)
        material.color = .init(tint: .init(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0))

        let eyeDesc = eye == .left ? "left" : "right"
        logger.info("🎨 Creating plane for \(eyeDesc) eye")

        // Create entity
        let entity = ModelEntity(
            mesh: mesh,
            materials: [material]
        )

        // STEREO POSITIONING: IPD separation for stereo effect
        // In ImmersiveSpace, position at origin with IPD separation
        let halfIPD = eyeSeparation / 2.0  // 63mm / 2 = 31.5mm = 0.0315m
        let xPosition: Float = eye == .left ? -halfIPD : halfIPD

        // Position at origin (z=0) - works in ImmersiveSpace
        entity.position = SIMD3(x: xPosition, y: 0, z: 0)

        logger.info("📍 Plane created for \(eyeDesc) eye at position (\(xPosition), 0, 0)")

        return entity
    }

    /// Create Metal texture from CVPixelBuffer
    private func createMetalTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        guard let textureCache = textureCache else { return nil }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        var cvTexture: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
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

    /// Make an RGBA8 texture with common usages
    private func makeRGBA8Texture(width: Int, height: Int) -> MTLTexture? {
        guard let device = metalDevice else { return nil }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        // Blit 복사에는 별도의 usage 플래그가 필요 없습니다.
        // RealityKit 머티리얼에서 샘플링만 하므로 .shaderRead만 설정합니다.
        descriptor.usage = [.shaderRead]
        return device.makeTexture(descriptor: descriptor)
    }

    /// Copy a region from source SBS texture to destination texture
    private func copyRegion(from src: MTLTexture,
                            sourceOriginX: Int,
                            width: Int,
                            height: Int,
                            to dst: MTLTexture) -> Bool {
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

    /// Update plane material with Metal texture (uses CPU fallback but optimized by RealityKit)
    /// If texture is nil, hides the entity
    private func updatePlaneMaterial(_ entity: ModelEntity?, with texture: MTLTexture?) {
        guard let entity else {
            if frameCounter <= 5 {
                logger.warning("⚠️ updatePlaneMaterial: entity is nil")
            }
            return
        }
        guard entity.model != nil else {
            if frameCounter <= 5 {
                logger.warning("⚠️ updatePlaneMaterial: entity.model is nil")
            }
            return
        }

        // If texture is nil, hide the entity
        guard let texture = texture else {
            entity.isEnabled = false
            if frameCounter <= 5 {
                logger.info("ℹ️ updatePlaneMaterial: hiding entity (texture is nil)")
            }
            return
        }

        // Show entity if it was hidden
        if !entity.isEnabled {
            entity.isEnabled = true
            logger.info("✅ updatePlaneMaterial: showing entity")
        }

        // Create TextureResource from Metal texture (CPU fallback path)
        // NOTE: This is the main performance bottleneck - CPU readback is expensive
        // RealityKit doesn't provide a direct GPU-to-GPU path for custom Metal textures
        // We've optimized by:
        // 1. Reducing frame rate to 30fps (skip every other frame)
        // 2. Reusing Metal textures via caching
        // 3. Using efficient blit operations for texture splitting
        do {
            let resource = try TextureResource(from: texture)
            var material = UnlitMaterial()
            material.color = .init(texture: .init(resource))
            entity.model?.materials = [material]

            if frameCounter <= 5 {
                logger.info("✅ updatePlaneMaterial: material updated successfully")
            }
        } catch {
            logger.error("❌ Failed to create TextureResource: \(error.localizedDescription)")
        }
    }
}

// MARK: - TextureResource helpers

extension TextureResource {
    // Prefer a helper that avoids CPU readback if the texture is IOSurface-backed.
    // This API isn’t public; emulate via MTKTextureLoader if needed.
    // Here we provide a convenience that tries fast path first using MTKTextureLoader’s CGImage path
    // only when necessary. In practice, RealityKit’s TextureResource has internal fast-paths
    // for IOSurface-backed textures on Apple platforms.

    static func generate(from metalTexture: MTLTexture) throws -> TextureResource {
        // Attempt to use an internal fast path when available via initializer that accepts MTLTexture.
        // If your deployment target exposes a TextureResource initializer for MTLTexture in the SDK,
        // prefer that directly. Otherwise, throw to let caller fall back.
        struct Unsupported: Error {}
        throw Unsupported()
    }

    /// CPU fallback: Create TextureResource from MTLTexture by reading back to CPU.
    /// Note: This is kept as a last resort; the main path avoids CPU copies.
    convenience init(from metalTexture: MTLTexture) throws {
        let width = metalTexture.width
        let height = metalTexture.height

        // Reduce logging to avoid spam (only log occasionally)
        // print("🔄 TextureResource(from:) - Creating from \(width)×\(height) texture")

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let dataSize = height * bytesPerRow

        var pixelData = [UInt8](repeating: 0, count: dataSize)

        let region = MTLRegion(
            origin: MTLOrigin(x: 0, y: 0, z: 0),
            size: MTLSize(width: width, height: height, depth: 1)
        )

        metalTexture.getBytes(
            &pixelData,
            bytesPerRow: bytesPerRow,
            from: region,
            mipmapLevel: 0
        )

        // print("🔄 TextureResource(from:) - Texture bytes read successfully")

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        // BGRA format - premultipliedFirst for BGRA
        let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)

        guard let provider = CGDataProvider(data: Data(pixelData) as CFData) else {
            // print("❌ TextureResource(from:) - Failed to create CGDataProvider")
            throw TextureResourceError.conversionFailed
        }

        // print("🔄 TextureResource(from:) - CGDataProvider created")

        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            // print("❌ TextureResource(from:) - Failed to create CGImage")
            throw TextureResourceError.conversionFailed
        }

        // print("🔄 TextureResource(from:) - CGImage created")

        try self.init(image: cgImage, options: .init(semantic: .color))
        // print("✅ TextureResource(from:) - TextureResource created successfully")
    }
}

enum TextureResourceError: Error {
    case conversionFailed
}
//
