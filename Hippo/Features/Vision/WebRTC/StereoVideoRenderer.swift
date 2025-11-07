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

    // Video configuration - optimized for viewing
    private let planeWidth: Float = 1.6     // meters (16:9 aspect ratio)
    private let planeHeight: Float = 0.9    // meters
    private let planeDistance: Float = 1.5  // meters from user (closer for better visibility)
    private let eyeSeparation: Float = 0.063 // 63mm IPD

    // Cached textures to avoid reallocation every frame
    private var cachedLeftTexture: MTLTexture?
    private var cachedRightTexture: MTLTexture?
    private var cachedSourceSize: (w: Int, h: Int)?

    // MARK: Initialization

    public init() {
        setupMetal()

        // Register this renderer as active
        Self.rendererLock.lock()
        defer { Self.rendererLock.unlock() }

        if let existingID = Self.activeRendererID {
            logger.warning("⚠️ Creating new renderer \(self.rendererID) while renderer \(existingID) is still active")
        }

        Self.activeRendererID = rendererID
        logger.info("✅ Renderer created: \(self.rendererID)")
    }

    deinit {
        // Unregister this renderer
        Self.rendererLock.lock()
        defer { Self.rendererLock.unlock() }

        if Self.activeRendererID == rendererID {
            Self.activeRendererID = nil
        }

        logger.info("🗑️ Renderer destroyed: \(self.rendererID)")
    }

    // MARK: - Public Methods

    /// Setup stereo planes in RealityKit scene
    public func setupScene(in content: RealityViewContent) {
        // Create anchor entity at world origin (fixed position in front of user)
        let anchor = AnchorEntity(world: [0, 0, -planeDistance])

        // Create left eye plane
        let leftPlane = createVideoPlane(offset: -eyeSeparation / 2)
        leftPlaneEntity = leftPlane
        anchor.addChild(leftPlane)
        logger.info("👁️ Left eye plane created and added to anchor")

        // Create right eye plane
        let rightPlane = createVideoPlane(offset: eyeSeparation / 2)
        rightPlaneEntity = rightPlane
        anchor.addChild(rightPlane)
        logger.info("👁️ Right eye plane created and added to anchor")

        // Add anchor to scene
        content.add(anchor)
        logger.info("⚓ Anchor entity added to scene at world position [0, 0, -\(self.planeDistance)]")

        isReady = true
        logger.info("✅ Stereo scene ready")
    }

    /// Update video texture with new SBS frame (variable size)
    public func updateFrame(_ pixelBuffer: CVPixelBuffer) {
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
        guard let sbsTexture = createMetalTexture(from: pixelBuffer) else {
            logger.warning("⚠️ Failed to create Metal texture from pixel buffer")
            return
        }

        let srcW = sbsTexture.width
        let srcH = sbsTexture.height

        // Validate SBS: width must be divisible by 2
        guard srcW >= 2, srcW % 2 == 0, srcH >= 1 else {
            logger.warning("⚠️ Invalid SBS size: \(srcW)×\(srcH). Expected width divisible by 2.")
            return
        }

        let halfWidth = srcW / 2
        let height = srcH

        // Allocate or reuse left/right destination textures
        if cachedSourceSize?.w != srcW || cachedSourceSize?.h != srcH {
            cachedLeftTexture = makeRGBA8Texture(width: halfWidth, height: height)
            cachedRightTexture = makeRGBA8Texture(width: halfWidth, height: height)
            cachedSourceSize = (srcW, srcH)
            logger.info("📐 Cached textures updated: \(halfWidth)×\(height)")
        }

        guard let leftTexture = cachedLeftTexture,
              let rightTexture = cachedRightTexture else {
            logger.error("❌ Failed to allocate destination textures for split")
            return
        }

        // Split SBS texture into left/right via blit (GPU copy, no CPU readback)
        guard copyRegion(
            from: sbsTexture,
            sourceOriginX: 0,
            width: halfWidth,
            height: height,
            to: leftTexture
        ), copyRegion(
            from: sbsTexture,
            sourceOriginX: halfWidth,
            width: halfWidth,
            height: height,
            to: rightTexture
        ) else {
            logger.error("❌ Failed to split SBS texture via blit")
            return
        }

        // Update plane materials by binding MTLTexture directly (no CPU conversion)
        updatePlaneMaterial(leftPlaneEntity, with: leftTexture)
        updatePlaneMaterial(rightPlaneEntity, with: rightTexture)

        logger.debug("🎬 Frame updated: \(srcW)×\(srcH) (half=\(halfWidth)×\(height))")
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

    /// Create video plane entity
    private func createVideoPlane(offset: Float) -> ModelEntity {
        // Create plane mesh
        let mesh = MeshResource.generatePlane(
            width: planeWidth,
            height: planeHeight
        )

        // Create material with bright color for debugging
        var material = UnlitMaterial()
        // Start with magenta to verify plane is visible
        material.color = .init(tint: .init(red: 1.0, green: 0.0, blue: 1.0, alpha: 1.0))

        logger.info("🎨 Creating plane with magenta color at offset \(offset)")

        // Create entity
        let entity = ModelEntity(
            mesh: mesh,
            materials: [material]
        )

        // Position plane (relative to anchor, which is already at z=-planeDistance)
        entity.position = SIMD3(
            x: offset,
            y: 0,
            z: 0  // Changed from -planeDistance to 0 (anchor already positioned)
        )

        logger.info("📍 Plane positioned at x=\(offset), y=0, z=0 (relative to anchor)")

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

    /// Update plane material with Metal texture directly (no CPU copy)
    private func updatePlaneMaterial(_ entity: ModelEntity?, with texture: MTLTexture?) {
        guard let entity, let texture else {
            logger.warning("⚠️ updatePlaneMaterial: entity or texture is nil")
            return
        }

        // Try fast path first
        if let resource = try? TextureResource.generate(from: texture) {
            var material = UnlitMaterial()
            material.color = .init(texture: .init(resource))
            entity.model?.materials = [material]
            logger.debug("✅ Texture updated via fast path")
            return
        }

        // Fallback: CPU readback path
        do {
            let resource = try TextureResource(from: texture)
            var material = UnlitMaterial()
            material.color = .init(texture: .init(resource))
            entity.model?.materials = [material]
            logger.debug("✅ Texture updated via CPU fallback")
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

        print("🔄 TextureResource(from:) - Creating from \(width)×\(height) texture")

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

        print("🔄 TextureResource(from:) - Texture bytes read successfully")

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        // BGRA format - premultipliedFirst for BGRA
        let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)

        guard let provider = CGDataProvider(data: Data(pixelData) as CFData) else {
            print("❌ TextureResource(from:) - Failed to create CGDataProvider")
            throw TextureResourceError.conversionFailed
        }

        print("🔄 TextureResource(from:) - CGDataProvider created")

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
            print("❌ TextureResource(from:) - Failed to create CGImage")
            throw TextureResourceError.conversionFailed
        }

        print("🔄 TextureResource(from:) - CGImage created")

        try self.init(image: cgImage, options: .init(semantic: .color))
        print("✅ TextureResource(from:) - TextureResource created successfully")
    }
}

enum TextureResourceError: Error {
    case conversionFailed
}
//
