//
//  CI_SBSComposer.swift
//  Hippo
//
//  CoreImage-based Side-by-Side composer
//  Composes left/right frames into Full SBS (3840×1080) or Half SBS (1920×1080)
//

import Foundation
import CoreImage
import CoreVideo
import CoreMedia
import os.log

// MARK: - SBS Composing Protocol

/// Protocol for Side-by-Side composition
public protocol SBSComposing: AnyObject {
    /// Compose left and right frames into SBS output
    func compose(
        left: CVPixelBuffer,
        right: CVPixelBuffer,
        leftSize: CGSize,
        rightSize: CGSize,
        config: SBSComposerConfig
    ) throws -> CVPixelBuffer
}

// MARK: - CoreImage SBS Composer

/// CoreImage-based SBS composer
/// Uses GPU-accelerated image processing for real-time composition
public final class CI_SBSComposer: SBSComposing {

    // MARK: Properties

    private let ciContext: CIContext
    private let logger = Logger(subsystem: "com.television.hippo", category: "Composer")

    // Debug counters
    private var composeCount: Int = 0
    private var sbsLayoutCount: Int = 0

    // MARK: Pixel Buffer Pool

    /// Pixel buffer pools for each output mode
    /// Reuses buffers to avoid allocation overhead
    private var pixelBufferPools: [SBSMode: CVPixelBufferPool] = [:]

    // MARK: Initialization

    public init() {
        // Create CIContext with Metal for GPU acceleration
        let options: [CIContextOption: Any] = [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.itur_709)!,
            .cacheIntermediates: true,
            .useSoftwareRenderer: false  // Use GPU (Metal)
        ]

        self.ciContext = CIContext(options: options)

        // Pre-create pixel buffer pools
        for mode in SBSMode.allCases {
            do {
                pixelBufferPools[mode] = try createPixelBufferPool(
                    width: Int(mode.outputSize.width),
                    height: Int(mode.outputSize.height)
                )
            } catch {
                logger.error("❌ Failed to create pixel buffer pool for \(mode.rawValue): \(error)")
            }
        }
    }

    // MARK: - Public Methods

    public func compose(
        left: CVPixelBuffer,
        right: CVPixelBuffer,
        leftSize: CGSize,
        rightSize: CGSize,
        config: SBSComposerConfig
    ) throws -> CVPixelBuffer {
        // Debug: Log first few compositions
        composeCount += 1
        if composeCount <= 3 {
            logger.info("🎨 [SBS Compose #\(self.composeCount)] Left: \(Int(leftSize.width))×\(Int(leftSize.height)), Right: \(Int(rightSize.width))×\(Int(rightSize.height)), Mode: \(config.mode.rawValue)")
        }

        // 1. Create CIImages from pixel buffers
        let leftImage = CIImage(cvPixelBuffer: left)
        let rightImage = CIImage(cvPixelBuffer: right)

        // 2. Normalize images (scale, crop) based on policy
        let targetEyeSize = config.mode.eyeSize
        let normalizedLeft = try normalize(
            image: leftImage,
            sourceSize: leftSize,
            targetSize: targetEyeSize,
            policy: config.policy
        )
        let normalizedRight = try normalize(
            image: rightImage,
            sourceSize: rightSize,
            targetSize: targetEyeSize,
            policy: config.policy
        )

        // 3. Compose side-by-side
        let composedImage = try composeSideBySide(
            left: normalizedLeft,
            right: normalizedRight,
            mode: config.mode
        )

        // 4. Render to output pixel buffer
        let outputBuffer = try createOutputBuffer(for: config.mode)
        try render(image: composedImage, to: outputBuffer)

        return outputBuffer
    }

    // MARK: - Private Methods: Normalization

    private func normalize(
        image: CIImage,
        sourceSize: CGSize,
        targetSize: CGSize,
        policy: NormalizePolicy
    ) throws -> CIImage {
        let sourceAspect = sourceSize.width / sourceSize.height
        let targetAspect = targetSize.width / targetSize.height

        switch policy {
        case .cropToMatchAspect:
            return try cropAndScale(
                image: image,
                sourceSize: sourceSize,
                sourceAspect: sourceAspect,
                targetSize: targetSize,
                targetAspect: targetAspect
            )

        case .scaleDownOnly:
            return try scaleDown(
                image: image,
                sourceSize: sourceSize,
                targetSize: targetSize
            )

        case .allowUpscale:
            return try scaleToFit(
                image: image,
                sourceSize: sourceSize,
                targetSize: targetSize
            )
        }
    }

    private func cropAndScale(
        image: CIImage,
        sourceSize: CGSize,
        sourceAspect: Double,
        targetSize: CGSize,
        targetAspect: Double
    ) throws -> CIImage {
        var processedImage = image

        // 1. Crop to match target aspect ratio (center crop)
        if abs(sourceAspect - targetAspect) > 0.01 {
            let cropRect: CGRect

            if sourceAspect > targetAspect {
                // Source is wider: crop width
                let cropWidth = sourceSize.height * targetAspect
                let cropX = (sourceSize.width - cropWidth) / 2
                cropRect = CGRect(x: cropX, y: 0, width: cropWidth, height: sourceSize.height)
            } else {
                // Source is taller: crop height
                let cropHeight = sourceSize.width / targetAspect
                let cropY = (sourceSize.height - cropHeight) / 2
                cropRect = CGRect(x: 0, y: cropY, width: sourceSize.width, height: cropHeight)
            }

            processedImage = processedImage.cropped(to: cropRect)
        }

        // 2. Scale to target size
        let croppedSize = processedImage.extent.size
        let scale = min(
            targetSize.width / croppedSize.width,
            targetSize.height / croppedSize.height
        )

        // Only scale down (scale <= 1.0)
        if scale < 1.0 {
            processedImage = try applyLanczosScale(image: processedImage, scale: scale)
        }

        return processedImage
    }

    private func scaleDown(
        image: CIImage,
        sourceSize: CGSize,
        targetSize: CGSize
    ) throws -> CIImage {
        let scale = min(
            targetSize.width / sourceSize.width,
            targetSize.height / sourceSize.height,
            1.0  // Never upscale
        )

        if scale < 1.0 {
            return try applyLanczosScale(image: image, scale: scale)
        }

        return image
    }

    private func scaleToFit(
        image: CIImage,
        sourceSize: CGSize,
        targetSize: CGSize
    ) throws -> CIImage {
        let scale = min(
            targetSize.width / sourceSize.width,
            targetSize.height / sourceSize.height
        )

        return try applyLanczosScale(image: image, scale: scale)
    }

    private func applyLanczosScale(image: CIImage, scale: CGFloat) throws -> CIImage {
        guard let filter = CIFilter(name: "CILanczosScaleTransform") else {
            throw VideoError.compositionFailed(reason: "Failed to create Lanczos filter")
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(scale, forKey: kCIInputScaleKey)
        filter.setValue(1.0, forKey: kCIInputAspectRatioKey)

        guard let outputImage = filter.outputImage else {
            throw VideoError.compositionFailed(reason: "Lanczos scale failed")
        }

        return outputImage
    }

    // MARK: - Private Methods: Composition

    private func composeSideBySide(
        left: CIImage,
        right: CIImage,
        mode: SBSMode
    ) throws -> CIImage {
        // Debug: Log composition details
        sbsLayoutCount += 1
        if sbsLayoutCount <= 3 {
            logger.info("📐 [SBS Layout #\(self.sbsLayoutCount)] Left at (0,0), Right at (\(Int(mode.eyeSize.width)),0), Output: \(Int(mode.outputSize.width))×\(Int(mode.outputSize.height))")
        }

        // Position left eye at (0, 0)
        let leftPositioned = left

        // Position right eye at (eyeWidth, 0)
        let rightTransform = CGAffineTransform(translationX: mode.eyeSize.width, y: 0)
        let rightPositioned = right.transformed(by: rightTransform)

        // Composite using source over
        guard let compositor = CIFilter(name: "CISourceOverCompositing") else {
            throw VideoError.compositionFailed(reason: "Failed to create compositor filter")
        }

        compositor.setValue(rightPositioned, forKey: kCIInputImageKey)
        compositor.setValue(leftPositioned, forKey: kCIInputBackgroundImageKey)

        guard let composited = compositor.outputImage else {
            throw VideoError.compositionFailed(reason: "Source over compositing failed")
        }

        // Crop to exact output size
        let outputRect = CGRect(origin: .zero, size: mode.outputSize)
        return composited.cropped(to: outputRect)
    }

    // MARK: - Private Methods: Rendering

    private func createOutputBuffer(for mode: SBSMode) throws -> CVPixelBuffer {
        guard let pool = pixelBufferPools[mode] else {
            throw VideoError.compositionFailed(reason: "No pixel buffer pool for mode \(mode)")
        }

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw VideoError.compositionFailed(reason: "Failed to create pixel buffer: \(status)")
        }

        return buffer
    }

    private func render(image: CIImage, to pixelBuffer: CVPixelBuffer) throws {
        let bounds = image.extent
        let colorSpace = CGColorSpace(name: CGColorSpace.itur_709)!
        ciContext.render(image, to: pixelBuffer, bounds: bounds, colorSpace: colorSpace)
    }

    // MARK: - Pixel Buffer Pool

    private func createPixelBufferPool(width: Int, height: Int) throws -> CVPixelBufferPool {
        let pixelBufferAttributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,  // BGRA for CoreImage
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary  // Enable IOSurface for Metal
        ]

        let poolAttributes: [CFString: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey: 3  // Pre-allocate 3 buffers
        ]

        var pool: CVPixelBufferPool?
        let status = CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            poolAttributes as CFDictionary,
            pixelBufferAttributes as CFDictionary,
            &pool
        )

        guard status == kCVReturnSuccess, let createdPool = pool else {
            throw VideoError.compositionFailed(reason: "Failed to create pixel buffer pool: \(status)")
        }

        return createdPool
    }
}
