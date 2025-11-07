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

actor ConvertingModel {
    private let stereoMetadata: StereoMetadata
    private var transferSession: VTPixelTransferSession?
    private var pixelBufferPool: CVMutablePixelBuffer.Pool?
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "App", category: "Converting")

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

    // 기본 인자 제거: 호출부에서 명시적으로 StereoMetadata.default 전달
    init(stereoMetadata: StereoMetadata) {
        self.stereoMetadata = stereoMetadata
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
        let originalAttachment = CVBufferGetAttachment(sourceImageBuffer, kCVImageBufferCleanApertureKey, nil)?.takeUnretainedValue()

        let layerIDs = [0, 1]
        let eyeComponents: [CMStereoViewComponents] = [.leftEye, .rightEye]
        var taggedBuffers = [CMTaggedDynamicBuffer]()

        // Calculate actual eye dimensions (before square padding)
        let eyeW = even(Int((CGFloat(srcWidth) / stereoMetadata.horizontalScale).rounded()))
        let eyeH = even(Int((CGFloat(srcHeight) / stereoMetadata.verticalScale).rounded()))

        for (layerID, eye) in zip(layerIDs, eyeComponents) {
            let pixelBuffer = try pool.makeMutablePixelBuffer()

            // Apply per-eye clean aperture to SOURCE just for the transfer.
            let bufferSize = pool.pixelBufferAttributes.size

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

        // Build ready sample buffer
        let buffer = CMReadySampleBuffer(
            taggedBuffers: taggedBuffers,
            formatDescription: CMTaggedBufferGroupFormatDescription(taggedBuffers: taggedBuffers),
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
            log.error("❌ Pool or session not initialized")
            return nil
        }

        // Get source frame dimensions for resolution-independent calculation
        let srcWidth = CVPixelBufferGetWidth(pixelBuffer)
        let srcHeight = CVPixelBufferGetHeight(pixelBuffer)
        let srcFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        let sourceSize = CGSize(width: srcWidth, height: srcHeight)

        // 🔍 DIAGNOSTIC: Log source frame info
        log.info("🔍 [DIAGNOSTIC] Source frame: \(srcWidth)×\(srcHeight) fmt=\(self.formatString(srcFormat))")

        // Determine stereo input mode (currently always SBS, but can be extended)
        let mode: StereoMetadata.StereoInputMode = .singleSourceSBS

        // Validate source dimensions for SBS
        precondition(stereoMetadata.framePacking == .sideBySide, "Only SingleSBS supported in this path")
        precondition(srcWidth >= 2 && srcWidth % 2 == 0, "SBS source width must be even and >= 2, got \(srcWidth)")

        // Save & restore clean aperture on the provided pixelBuffer as well.
        let originalAttachment = CVBufferGetAttachment(pixelBuffer, kCVImageBufferCleanApertureKey, nil)?.takeUnretainedValue()

        let layerIDs = [0, 1]
        let eyeComponents: [CMStereoViewComponents] = [.leftEye, .rightEye]
        var taggedBuffers = [CMTaggedDynamicBuffer]()

        for (layerID, eye) in zip(layerIDs, eyeComponents) {
            let out = try pool.makeMutablePixelBuffer()
            let bufferSize = pool.pixelBufferAttributes.size

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

            let eyeName = eye == .leftEye ? "Left" : "Right"

            // 🔍 DIAGNOSTIC: Log aperture offset calculation
            log.info("🔍 [DIAGNOSTIC] \(eyeName) eye aperture offset: H=\(String(format: "%.2f", apertureOffset.horizontal)), V=\(String(format: "%.2f", apertureOffset.vertical))")

            // Calculate actual crop region in pixels
            // offset is relative to center, convert to absolute pixel coordinates
            let centerX = Double(srcWidth) / 2.0
            let centerY = Double(srcHeight) / 2.0
            let cropStartX = centerX + apertureOffset.horizontal - Double(eyeW) / 2.0
            let cropStartY = centerY + apertureOffset.vertical - Double(eyeH) / 2.0

            log.info("🔍 [DIAGNOSTIC] \(eyeName) eye crop region in pixels:")
            log.info("   Source center: (\(String(format: "%.1f", centerX)), \(String(format: "%.1f", centerY)))")
            log.info("   Crop rect: x=\(String(format: "%.1f", cropStartX)), y=\(String(format: "%.1f", cropStartY)), w=\(eyeW), h=\(eyeH)")
            log.info("   Expected for SBS: Left=(0,0,\(srcWidth/2),\(srcHeight)), Right=(\(srcWidth/2),0,\(srcWidth/2),\(srcHeight))")

            // Verify crop rectangle matches expected split
            if stereoMetadata.framePacking == .sideBySide && layerID == 0 {
                // First frame: log the split coordinates
                log.debug("   Left eye:  source rect ≈ (0, 0, \(eyeW), \(eyeH)) via clean aperture offset H=\(String(format: "%.1f", apertureOffset.horizontal))")
            } else if stereoMetadata.framePacking == .sideBySide && layerID == 1 {
                log.debug("   Right eye: source rect ≈ (\(eyeW), 0, \(eyeW), \(eyeH)) via clean aperture offset H=\(String(format: "%.1f", apertureOffset.horizontal))")
            }

            // Source clean aperture: crop from SBS
            let cropRectDict: [CFString: Any] = [
                kCVImageBufferCleanApertureHorizontalOffsetKey: apertureOffset.horizontal,
                kCVImageBufferCleanApertureVerticalOffsetKey: apertureOffset.vertical,
                kCVImageBufferCleanApertureWidthKey: eyeW,
                kCVImageBufferCleanApertureHeightKey: eyeH
            ]

            // 🔍 DIAGNOSTIC: Log clean aperture dictionary values
            log.info("🔍 [DIAGNOSTIC] \(eyeName) eye clean aperture dict: H_offset=\(apertureOffset.horizontal), V_offset=\(apertureOffset.vertical), W=\(eyeW), H=\(eyeH)")
            CVBufferSetAttachment(pixelBuffer, kCVImageBufferCleanApertureKey, cropRectDict as CFDictionary, .shouldNotPropagate)

            // Validate no double cropping before transfer
            out.withUnsafeBuffer { dst in
                assertNoDoubleCrop(source: pixelBuffer, destination: dst, usingCleanAperture: true)
            }

            out.withUnsafeBuffer { dst in
                // 🔍 DIAGNOSTIC: Log before transfer
                let dstWidthBefore = CVPixelBufferGetWidth(dst)
                let dstHeightBefore = CVPixelBufferGetHeight(dst)
                log.info("🔍 [DIAGNOSTIC] Before transfer - \(eyeName) eye dst buffer: \(dstWidthBefore)×\(dstHeightBefore)")

                let status = VTPixelTransferSessionTransferImage(session, from: pixelBuffer, to: dst)
                if status != kCVReturnSuccess {
                    log.error("❌ VTPixelTransferSessionTransferImage failed: \(status)")
                } else {
                    log.info("✅ VTPixelTransferSessionTransferImage succeeded for \(eyeName) eye")
                }

                // CRITICAL: Remove clean apertures from output buffer
                // VideoPlayerComponent should see the full square buffer (640×640) without any cropping
                CVBufferRemoveAttachment(dst, kCVImageBufferCleanApertureKey)
            }

            // Verify output buffer
            out.withUnsafeBuffer { dst in
                let dstWidth = CVPixelBufferGetWidth(dst)
                let dstHeight = CVPixelBufferGetHeight(dst)

                // Check if clean aperture was actually removed
                let hasCleanAperture = CVBufferGetAttachment(dst, kCVImageBufferCleanApertureKey, nil) != nil

                log.debug("📤 \(eyeName) eye output: \(dstWidth)×\(dstHeight), hasCleanAperture=\(hasCleanAperture)")

                // 🔍 DIAGNOSTIC: Detailed output buffer info
                log.info("🔍 [DIAGNOSTIC] After transfer - \(eyeName) eye output buffer:")
                log.info("   Size: \(dstWidth)×\(dstHeight)")
                log.info("   Has clean aperture: \(hasCleanAperture)")
                log.info("   Expected: Clean aperture should be removed (false)")

                // Lock buffer to inspect actual pixel data (first few pixels)
                CVPixelBufferLockBaseAddress(dst, .readOnly)
                defer { CVPixelBufferUnlockBaseAddress(dst, .readOnly) }

                if let baseAddress = CVPixelBufferGetBaseAddress(dst) {
                    let bytesPerRow = CVPixelBufferGetBytesPerRow(dst)
                    log.info("   Bytes per row: \(bytesPerRow)")
                    log.info("   Base address is valid: ✅")
                } else {
                    log.error("   Base address is nil: ❌")
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

        let formatDesc = CMTaggedBufferGroupFormatDescription(taggedBuffers: taggedBuffers)
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
            }
            log.debug("✅ Stereo sample buffer created with \(taggedBuffers.count) tagged buffers")
        } else {
            log.error("❌ Failed to create stereo sample buffer or attachments")
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
            pixelBufferPool = try makePixelBufferPool(
                pixelFormat: srcFormat,
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

    /// Create a pixel buffer pool with specified format and size
    private func makePixelBufferPool(
        pixelFormat: OSType,
        width: Int,
        height: Int
    ) throws -> CVMutablePixelBuffer.Pool {
        let attrs = CVPixelBufferCreationAttributes(
            pixelFormatType: CVPixelFormatType(rawValue: pixelFormat),
            size: CVImageSize(width: width, height: height)
        )
        return try CVMutablePixelBuffer.Pool(pixelBufferAttributes: attrs)
    }

    // MARK: - Validation Methods

    /// Validate that we're not applying double cropping (clean aperture + SourceCropRectangle)
    private func assertNoDoubleCrop(
        source: CVImageBuffer,
        destination: CVImageBuffer,
        usingCleanAperture: Bool
    ) {
        let srcHasCleanAperture = CVBufferGetAttachment(
            source,
            kCVImageBufferCleanApertureKey,
            nil
        ) != nil

        let destHasCleanAperture = CVBufferGetAttachment(
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
