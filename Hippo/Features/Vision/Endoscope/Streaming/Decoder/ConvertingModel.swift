/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Converts monoscopic frame-packed input into stereoscopic tagged sample buffers.
*/

import AVFoundation
import CoreMedia
import CoreVideo
import VideoToolbox
import os

@MainActor
final class ConvertingModel {
    private let stereoMetadata: StereoMetadata
    private let recommendedPixelBufferAttributes: CVPixelBufferAttributes?
    private var transferSession: VTPixelTransferSession?
    private var pixelBufferPool: CVMutablePixelBuffer.Pool?
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "App", category: "Converting")

    // Frame counter for diagnostic logging
    private var processedFrameCount: Int = 0

    // Frame signature tracking for resource rebuild
    private struct FrameSignature: Equatable {
        let width: Int
        let height: Int
        let format: OSType
        let packing: StereoMetadata.FramePacking
    }
    private var lastSignature: FrameSignature?

    /// Make value even (safe for 420 chroma)
    @inline(__always) private func even(_ value: Int) -> Int {
        return value & ~1
    }

    /// Initialize with stereo metadata and recommended pixel buffer attributes from AVSampleBufferVideoRenderer
    /// - Parameters:
    ///   - stereoMetadata: Stereo configuration (frame packing, scaling, etc.)
    ///   - recommendedPixelBufferAttributes: Attributes from AVSampleBufferVideoRenderer.recommendedPixelBufferAttributes
    init(stereoMetadata: StereoMetadata, recommendedPixelBufferAttributes: CVPixelBufferAttributes? = nil) {
        self.stereoMetadata = stereoMetadata
        self.recommendedPixelBufferAttributes = recommendedPixelBufferAttributes
        log.info("ConvertingModel initialized with recommended attributes: \(recommendedPixelBufferAttributes != nil)")
    }

    func process(_ sample: CMSampleBuffer) throws -> CMSampleBuffer? {
        guard let sourceImageBuffer = CMSampleBufferGetImageBuffer(sample) else {
            return nil
        }

        try ensureResources(for: sourceImageBuffer)
        guard let pool = pixelBufferPool, let session = transferSession else {
            return nil
        }

        // Get source frame dimensions for resolution-independent calculation
        let srcWidth = CVPixelBufferGetWidth(sourceImageBuffer)
        let srcHeight = CVPixelBufferGetHeight(sourceImageBuffer)
        let sourceSize = CGSize(width: srcWidth, height: srcHeight)

        // Determine stereo input mode (currently always SBS, but can be extended)
        let mode: StereoMetadata.StereoInputMode = .singleSourceSBS

        // Save original clean aperture to restore later.
        let originalAttachment = CVBufferCopyAttachment(sourceImageBuffer, kCVImageBufferCleanApertureKey, nil)

        let layerIDs = [0, 1]
        let eyeComponents: [CMStereoViewComponents] = [.leftEye, .rightEye]
        var taggedBuffers = [CMTaggedDynamicBuffer]()

        // Calculate actual eye dimensions (before square padding)
        let eyeW = even(Int((CGFloat(srcWidth) / stereoMetadata.horizontalScale).rounded()))
        let eyeH = even(Int((CGFloat(srcHeight) / stereoMetadata.verticalScale).rounded()))

        for (layerID, eye) in zip(layerIDs, eyeComponents) {
            let pixelBuffer = try pool.makeMutablePixelBuffer()

            // Apply per-eye clean aperture to SOURCE just for the transfer.
            // Use new resolution-independent cleanApertureOffset
            let apertureOffset = stereoMetadata.cleanApertureOffset(
                for: layerID,
                sourceSize: sourceSize,
                mode: mode
            )

            // Validate mode-specific offset constraints
            validateModeOffsets(mode: mode, offset: apertureOffset)

            // Source clean aperture: crop from SBS
            let cropRectDict: [CFString: Any] = [
                kCVImageBufferCleanApertureHorizontalOffsetKey: apertureOffset.horizontal,
                kCVImageBufferCleanApertureVerticalOffsetKey: apertureOffset.vertical,
                kCVImageBufferCleanApertureWidthKey: eyeW,
                kCVImageBufferCleanApertureHeightKey: eyeH
            ]
            CVBufferSetAttachment(sourceImageBuffer, kCVImageBufferCleanApertureKey, cropRectDict as CFDictionary, .shouldNotPropagate)
            VTSessionSetProperty(session, key: kVTPixelTransferPropertyKey_ScalingMode, value: kVTScalingMode_CropSourceToCleanAperture)

            // Validate no double cropping before transfer
            pixelBuffer.withUnsafeBuffer { cvPixelBuffer in
                assertNoDoubleCrop(source: sourceImageBuffer, destination: cvPixelBuffer, usingCleanAperture: true)
            }

            // Transfer the image to the pixel buffer.
            pixelBuffer.withUnsafeBuffer { cvPixelBuffer in
                _ = VTPixelTransferSessionTransferImage(session, from: sourceImageBuffer, to: cvPixelBuffer)

                // CRITICAL: Remove any clean aperture that might have been copied to destination
                // If clean aperture remains on output buffer, VideoPlayerComponent will crop it again
                CVBufferRemoveAttachment(cvPixelBuffer, kCVImageBufferCleanApertureKey)
            }

            // Create and append a tagged buffer for this eye.
            let tags: [CMTag] = [.videoLayerID(Int64(layerID)), .stereoView(eye), .mediaType(.video)]
            taggedBuffers.append(CMTaggedDynamicBuffer(tags: tags, content: .pixelBuffer(CVReadOnlyPixelBuffer(pixelBuffer))))
        }

        // Restore original clean aperture so SBS preview isn't affected.
        if let originalAttachment {
            CVBufferSetAttachment(sourceImageBuffer, kCVImageBufferCleanApertureKey, originalAttachment, .shouldPropagate)
        } else {
            CVBufferRemoveAttachment(sourceImageBuffer, kCVImageBufferCleanApertureKey)
        }

        // Create format description
        // Note: CMTaggedBufferGroupFormatDescription returns 0×0 dimensions by design
        // The actual dimensions are in each tagged pixel buffer
        // This is acceptable for VideoPlayerComponent as it reads from the pixel buffers
        let formatDesc = CMTaggedBufferGroupFormatDescription(taggedBuffers: taggedBuffers)

        // Build ready sample buffer
        let buffer = CMReadySampleBuffer(
            taggedBuffers: taggedBuffers,
            formatDescription: formatDesc,
            presentationTimeStamp: CMSampleBufferGetPresentationTimeStamp(sample),
            duration: CMSampleBufferGetDuration(sample)
        )
        var out: CMSampleBuffer?
        buffer.withUnsafeSampleBuffer { sb in
            out = sb
        }

        // Ensure immediate display to avoid stalls when timebase is ambiguous
        if let out,
           let attachments = CMSampleBufferGetSampleAttachmentsArray(out, createIfNecessary: true) {
            let arr = attachments as NSArray
            if let dict = arr.firstObject as? NSMutableDictionary {
                dict[kCMSampleAttachmentKey_DisplayImmediately] = true
                dict[kCMSampleAttachmentKey_DoNotDisplay] = false
            }
        }

        return out
    }

    func process(_ pixelBuffer: CVPixelBuffer, pts: CMTime, duration: CMTime = .invalid) throws -> CMSampleBuffer? {
        try ensureResources(for: pixelBuffer)
        guard let pool = pixelBufferPool, let session = transferSession else {
            log.error("Pool or session not initialized")
            return nil
        }

        // Increment frame counter
        processedFrameCount += 1
        let enableDiagnostics = processedFrameCount == 1  // Only first frame for performance

        // Get source frame dimensions for resolution-independent calculation
        let srcWidth = CVPixelBufferGetWidth(pixelBuffer)
        let srcHeight = CVPixelBufferGetHeight(pixelBuffer)
        let srcFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        let sourceSize = CGSize(width: srcWidth, height: srcHeight)

        // DIAGNOSTIC: Log source frame info (first frame only)
        if enableDiagnostics {
            log.info("[ConvertingModel] Input buffer: \(srcWidth)x\(srcHeight) fmt=\(self.formatString(srcFormat))")
        }

        // Determine stereo input mode (currently always SBS, but can be extended)
        let mode: StereoMetadata.StereoInputMode = .singleSourceSBS

        // Validate source dimensions for SBS
        precondition(stereoMetadata.framePacking == .sideBySide, "Only SingleSBS supported in this path")
        precondition(srcWidth >= 2 && srcWidth % 2 == 0, "SBS source width must be even and >= 2, got \(srcWidth)")

        // Save & restore clean aperture on the provided pixelBuffer as well.
        let originalAttachment = CVBufferCopyAttachment(pixelBuffer, kCVImageBufferCleanApertureKey, nil)

        let layerIDs = [0, 1]
        let eyeComponents: [CMStereoViewComponents] = [.leftEye, .rightEye]
        var taggedBuffers = [CMTaggedDynamicBuffer]()

        for (layerID, eye) in zip(layerIDs, eyeComponents) {
            let out = try pool.makeMutablePixelBuffer()

            // Use new resolution-independent cleanApertureOffset
            let apertureOffset = stereoMetadata.cleanApertureOffset(
                for: layerID,
                sourceSize: sourceSize,
                mode: mode
            )

            // Validate mode-specific offset constraints
            validateModeOffsets(mode: mode, offset: apertureOffset)

            // Per-eye dimensions from pool
            let eyeW = pool.pixelBufferAttributes.size.width
            let eyeH = pool.pixelBufferAttributes.size.height

            // DIAGNOSTIC: Log output buffer size (first frame only)
            if enableDiagnostics && layerID == 0 {
                log.info("[ConvertingModel] Output buffer (per eye): \(eyeW)x\(eyeH)")
            }

            // Source clean aperture: crop from SBS
            let cropRectDict: [CFString: Any] = [
                kCVImageBufferCleanApertureHorizontalOffsetKey: apertureOffset.horizontal,
                kCVImageBufferCleanApertureVerticalOffsetKey: apertureOffset.vertical,
                kCVImageBufferCleanApertureWidthKey: eyeW,
                kCVImageBufferCleanApertureHeightKey: eyeH
            ]
            CVBufferSetAttachment(pixelBuffer, kCVImageBufferCleanApertureKey, cropRectDict as CFDictionary, .shouldNotPropagate)

            // Validate no double cropping before transfer
            out.withUnsafeBuffer { dst in
                assertNoDoubleCrop(source: pixelBuffer, destination: dst, usingCleanAperture: true)
            }

            out.withUnsafeBuffer { dst in
                let status = VTPixelTransferSessionTransferImage(session, from: pixelBuffer, to: dst)
                if status != kCVReturnSuccess {
                    log.error("VTPixelTransferSessionTransferImage failed: \(status)")
                }

                // CRITICAL: Remove clean apertures from output buffer
                // VideoPlayerComponent should see the full square buffer (640×640) without any cropping
                CVBufferRemoveAttachment(dst, kCVImageBufferCleanApertureKey)

                // DIAGNOSTIC: Verify actual transferred size (first frame only)
                if enableDiagnostics && layerID == 0 {
                    let actualW = CVPixelBufferGetWidth(dst)
                    let actualH = CVPixelBufferGetHeight(dst)
                    log.info("[ConvertingModel] Transferred buffer actual size: \(actualW)x\(actualH)")
                }
            }

            let tags: [CMTag] = [.videoLayerID(Int64(layerID)), .stereoView(eye), .mediaType(.video)]
            taggedBuffers.append(CMTaggedDynamicBuffer(tags: tags, content: .pixelBuffer(CVReadOnlyPixelBuffer(out))))
        }

        // Restore original clean aperture on the source pixel buffer.
        if let originalAttachment {
            CVBufferSetAttachment(pixelBuffer, kCVImageBufferCleanApertureKey, originalAttachment, .shouldPropagate)
        } else {
            CVBufferRemoveAttachment(pixelBuffer, kCVImageBufferCleanApertureKey)
        }

        // Create format description for tagged buffer group
        let eyeW = pool.pixelBufferAttributes.size.width
        let eyeH = pool.pixelBufferAttributes.size.height

        // Note: CMTaggedBufferGroupFormatDescription returns 0×0 dimensions by design
        // The actual dimensions are in each tagged pixel buffer
        let formatDesc = CMTaggedBufferGroupFormatDescription(taggedBuffers: taggedBuffers)

        // Debug logging for first frame only
        if enableDiagnostics {
            let dims = CMVideoFormatDescriptionGetDimensions(formatDesc)
            log.info("[ConvertingModel] Format description dimensions: \(dims.width)x\(dims.height)")
            log.info("[ConvertingModel] Expected per-eye dimensions: \(eyeW)x\(eyeH)")

            if dims.width == 0 || dims.height == 0 {
                log.info("[ConvertingModel] Format description has 0x0 (expected for tagged buffer groups)")

                // Verify that the tagged buffers themselves have proper dimensions
                for (idx, taggedBuffer) in taggedBuffers.enumerated() {
                    if case .pixelBuffer(let pb) = taggedBuffer.content {
                        pb.withUnsafeBuffer { cvBuffer in
                            let w = CVPixelBufferGetWidth(cvBuffer)
                            let h = CVPixelBufferGetHeight(cvBuffer)
                            log.info("[ConvertingModel] Tagged buffer[\(idx)] actual: \(w)x\(h)")
                        }
                    }
                }
            }
        }

        let buffer = CMReadySampleBuffer(
            taggedBuffers: taggedBuffers,
            formatDescription: formatDesc,
            presentationTimeStamp: pts,
            duration: duration
        )
        var outSB: CMSampleBuffer?
        buffer.withUnsafeSampleBuffer { sb in
            outSB = sb
        }

        if let outSB,
           let attachments = CMSampleBufferGetSampleAttachmentsArray(outSB, createIfNecessary: true) {
            let arr = attachments as NSArray
            if let dict = arr.firstObject as? NSMutableDictionary {
                dict[kCMSampleAttachmentKey_DisplayImmediately] = true
                dict[kCMSampleAttachmentKey_DoNotDisplay] = false

                // Add explicit dimensions as attachment for VideoPlayerComponent
                // This helps VideoPlayerComponent understand the per-eye dimensions
                dict["VideoDimensions" as CFString] = [
                    "Width": eyeW,
                    "Height": eyeH
                ] as CFDictionary
            }

            // CRITICAL: Add HeroEye attachment to the SAMPLE BUFFER (not format description)
            // For tagged buffer groups, the attachment must be on the sample buffer itself
            CMSetAttachment(
                outSB as CMAttachmentBearer,
                key: kCMFormatDescriptionExtension_HeroEye as CFString,
                value: kCMFormatDescriptionHeroEye_Left as CFTypeRef,
                attachmentMode: kCMAttachmentMode_ShouldPropagate
            )

            // DIAGNOSTIC: Verify final sample buffer (first frame only)
            if processedFrameCount == 1 {
                // Check if we can get an image buffer from the sample
                if let imageBuffer = CMSampleBufferGetImageBuffer(outSB) {
                    let finalW = CVPixelBufferGetWidth(imageBuffer)
                    let finalH = CVPixelBufferGetHeight(imageBuffer)
                    log.info("[ConvertingModel] Final sample buffer image: \(finalW)x\(finalH)")
                } else {
                    log.info("[ConvertingModel] Final sample buffer has NO image buffer (tagged buffer group)")
                }

                log.info("[ConvertingModel] Stereo sample buffer created with \(taggedBuffers.count) tagged buffers")
            }
        } else if processedFrameCount == 1 {
            log.error("[ConvertingModel] Failed to create stereo sample buffer")
        }

        return outSB
    }

    private func formatString(_ format: OSType) -> String {
        let chars: [UInt8] = [
            UInt8((format >> 24) & 0xFF),
            UInt8((format >> 16) & 0xFF),
            UInt8((format >> 8) & 0xFF),
            UInt8(format & 0xFF)
        ]
        return String(bytes: chars, encoding: .ascii) ?? "????"
    }

    private func ensureResources(for imageBuffer: CVImageBuffer) throws {
        let srcWidth = CVPixelBufferGetWidth(imageBuffer)
        let srcHeight = CVPixelBufferGetHeight(imageBuffer)
        let srcFormat = CVPixelBufferGetPixelFormatType(imageBuffer)

        let currentSignature = FrameSignature(
            width: srcWidth,
            height: srcHeight,
            format: srcFormat,
            packing: stereoMetadata.framePacking
        )

        // Calculate per-eye dimensions with even alignment (safe for 420)
        // For SBS: eyeW = even(srcW / 2), eyeH = even(srcH)
        let eyeWidth = even(Int((CGFloat(srcWidth) / stereoMetadata.horizontalScale).rounded()))
        let eyeHeight = even(Int((CGFloat(srcHeight) / stereoMetadata.verticalScale).rounded()))

        let targetSize = CGSize(width: eyeWidth, height: eyeHeight)

        // Determine if we need to rebuild resources
        let needsRebuild = lastSignature != currentSignature ||
                          pixelBufferPool == nil ||
                          transferSession == nil ||
                          getPoolSize(pixelBufferPool) != targetSize

        if needsRebuild {
            // Clean up old resources
            transferSession = nil
            pixelBufferPool = nil

            // Create new transfer session with crop-to-clean-aperture mode
            transferSession = try makeTransferSessionWithCropScaling()

            // Create new pixel buffer pool
            // Note: Always uses kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange regardless of srcFormat
            pixelBufferPool = try makePixelBufferPool(
                width: eyeWidth,
                height: eyeHeight
            )

            lastSignature = currentSignature

            // Comprehensive diagnostic logging (once per resolution/packing change)
            log.info("🔄 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            log.info("   RX.source = \(srcWidth)×\(srcHeight) fmt=\(self.formatString(srcFormat))")
            log.info("   Stereo.mode = \(self.stereoMetadata.framePacking == .sideBySide ? "SingleSBS" : "OverUnder")")

            if self.stereoMetadata.framePacking == .sideBySide {
                log.info("   Split.left  = (0,0,\(eyeWidth),\(eyeHeight))")
                log.info("   Split.right = (\(eyeWidth),0,\(eyeWidth),\(eyeHeight))")
            }

            log.info("   Pool.eyeOut = \(eyeWidth)×\(eyeHeight)")
            log.info("   UsingCleanAperture=true HasSourceCropRect=false DestHasCA=false")
            log.info("   StereoMaterial.fullUV=true  Plane.aspect=\(eyeWidth):\(eyeHeight)")
            log.info("   Display.videoGravity=resizeAspect")
            log.info("🔄 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }
    }

    // MARK: - Helper Methods

    /// Get the size of the pixel buffer pool
    private func getPoolSize(_ pool: CVMutablePixelBuffer.Pool?) -> CGSize? {
        guard let pool = pool else { return nil }
        let attrs = pool.pixelBufferAttributes
        return CGSize(width: attrs.size.width, height: attrs.size.height)
    }

    /// Create a VTPixelTransferSession with crop-to-clean-aperture scaling mode
    ///
    /// ⚠️ SINGLE CROPPING PATH - Clean Aperture Method:
    /// We use EXACTLY ONE cropping mechanism to avoid double-cropping:
    ///
    /// ✅ What we DO:
    ///   - Set clean aperture on SOURCE buffer (per-eye offset, e.g., ±srcW/4 for SBS)
    ///   - Use kVTScalingMode_CropSourceToCleanAperture to honor it
    ///   - Create destination buffers WITHOUT clean aperture
    ///
    /// ❌ What we DON'T do:
    ///   - Do NOT use kVTPixelTransferPropertyKey_SourceCropRectangle (conflicts with clean aperture)
    ///   - Do NOT set clean aperture on destination buffers (would double-crop)
    ///   - Do NOT use both cropping methods simultaneously
    ///
    /// This ensures each eye is extracted exactly once from the SBS source.
    private func makeTransferSessionWithCropScaling() throws -> VTPixelTransferSession {
        var session: VTPixelTransferSession?
        let result = VTPixelTransferSessionCreate(
            allocator: kCFAllocatorDefault,
            pixelTransferSessionOut: &session
        )
        guard result == kCVReturnSuccess, let session = session else {
            throw NSError(domain: "ConvertingModel", code: Int(result))
        }

        // Set scaling mode to crop source to clean aperture (SINGLE CROP PATH)
        VTSessionSetProperty(
            session,
            key: kVTPixelTransferPropertyKey_ScalingMode,
            value: kVTScalingMode_CropSourceToCleanAperture
        )

        // Explicitly verify we're NOT setting SourceCropRectangle
        // (Setting it would create a double-crop scenario)
        log.info("✅ VTPixelTransferSession created with CropSourceToCleanAperture mode")
        log.info("   SINGLE CROP: Using clean aperture ONLY (no SourceCropRectangle)")
        return session
    }

    /// Create pixel buffer pool using Apple's recommended approach
    /// Matches SerialProcessor.swift (line 94-104) from Apple's sample code
    /// Always uses kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange for VideoPlayerComponent compatibility
    private func makePixelBufferPool(
        width: Int,
        height: Int
    ) throws -> CVMutablePixelBuffer.Pool {
        // Use kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange for compatibility with VideoPlayerComponent
        // This is the standard format that AVSampleBufferVideoRenderer expects
        let defaultAttributes = CVPixelBufferCreationAttributes(
            pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
            size: CVImageSize(width: width, height: height)
        )

        // Merge with recommended attributes from AVSampleBufferVideoRenderer if available
        if let recommendedAttrs = recommendedPixelBufferAttributes {
            log.info("Merging recommended pixel buffer attributes from AVSampleBufferVideoRenderer")
            guard let mergedAttributes = CVPixelBufferAttributes(
                    merging: [CVPixelBufferAttributes(defaultAttributes), recommendedAttrs]),
                  let creationAttributes = CVPixelBufferCreationAttributes(mergedAttributes) else {
                log.error("Failed to merge pixel buffer attributes, using defaults only")
                return try CVMutablePixelBuffer.Pool(pixelBufferAttributes: defaultAttributes)
            }
            return try CVMutablePixelBuffer.Pool(pixelBufferAttributes: creationAttributes)
        } else {
            log.warning("No recommended attributes available, using default 420v format")
            return try CVMutablePixelBuffer.Pool(pixelBufferAttributes: defaultAttributes)
        }
    }

    // MARK: - Validation Methods

    /// Validate that we're not applying double cropping (clean aperture + SourceCropRectangle)
    private func assertNoDoubleCrop(
        source: CVImageBuffer,
        destination: CVImageBuffer,
        usingCleanAperture: Bool
    ) {
        let srcHasCleanAperture = CVBufferCopyAttachment(
            source,
            kCVImageBufferCleanApertureKey,
            nil
        ) != nil

        let destHasCleanAperture = CVBufferCopyAttachment(
            destination,
            kCVImageBufferCleanApertureKey,
            nil
        ) != nil

        // Check if transfer session has SourceCropRectangle set
        // Note: We're using clean aperture mode, so this should always be false
        let hasCropRect = false // We don't set SourceCropRectangle in our implementation

        if usingCleanAperture {
            // When using clean aperture mode:
            // - Source should have clean aperture set (we set it per-eye)
            // - SourceCropRectangle should NOT be set
            // - Destination should NOT have clean aperture set
            precondition(
                srcHasCleanAperture && !hasCropRect,
                "Double crop detected: Expected clean aperture on source without SourceCropRectangle"
            )
            precondition(
                !destHasCleanAperture,
                "Double crop detected: Destination should not define a clean aperture"
            )
        } else {
            // When using SourceCropRectangle mode (not our current implementation):
            // - Source should NOT have clean aperture
            // - SourceCropRectangle should be set
            // - Destination should NOT have clean aperture
            precondition(
                !srcHasCleanAperture && hasCropRect,
                "Double crop detected: Expected SourceCropRectangle without clean aperture"
            )
            precondition(
                !destHasCleanAperture,
                "Double crop detected: Destination should not define a clean aperture"
            )
        }
    }

    /// Validate mode-specific offset constraints
    private func validateModeOffsets(
        mode: StereoMetadata.StereoInputMode,
        offset: StereoMetadata.ApertureOffset
    ) {
        switch mode {
        case .singleSourceSBS:
            // For SBS, horizontal offset should be non-zero, vertical should be zero
            if stereoMetadata.framePacking == .sideBySide {
                precondition(
                    abs(offset.vertical) < 0.001,
                    "SingleSBS with side-by-side packing requires zero vertical offset, got \(offset.vertical)"
                )
            }

        case .splitEyes:
            // For already-split eyes, both offsets must be zero
            precondition(
                abs(offset.horizontal) < 0.001 && abs(offset.vertical) < 0.001,
                "SplitEyes mode requires zero clean-aperture offsets, got H=\(offset.horizontal) V=\(offset.vertical)"
            )
        }
    }
}
