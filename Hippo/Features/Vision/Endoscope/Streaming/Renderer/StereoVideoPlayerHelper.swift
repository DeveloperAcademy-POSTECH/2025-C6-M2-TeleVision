//
//  StereoVideoPlayerHelper.swift
//  Hippo
//
//  Helper functions for processing pixel buffers for VideoPlayer
//  Supports: Raw SBS, Left-only Mono, and Stereo modes
//

import Foundation
import AVFoundation
import CoreVideo
import CoreMedia
import VideoToolbox
import os.log

/// Helper class for processing pixel buffers for stereo video rendering
@MainActor
public final class StereoVideoPlayerHelper {

    private let logger = Logger(subsystem: "com.television.hippo", category: "StereoHelper")

    // MARK: - 2단계: Left-only Mono Mode

    /// Extract left eye only from SBS (Side-by-Side) pixel buffer
    /// Uses VTPixelTransferSession for reliable color handling (same as Stereo 3D)
    /// - Parameter sbs: Source SBS pixel buffer (e.g., 1920×540)
    /// - Returns: Left-only pixel buffer (e.g., 960×540) in NV12 format
    public func makeLeftEyeMono(from sbs: CVPixelBuffer) -> CVPixelBuffer? {
        // 1. Validate
        guard validateSBSBuffer(sbs) else {
            return nil
        }

        let srcWidth = CVPixelBufferGetWidth(sbs)
        let srcHeight = CVPixelBufferGetHeight(sbs)
        let format = CVPixelBufferGetPixelFormatType(sbs)

        let dstWidth = srcWidth / 2
        let dstHeight = srcHeight

        // 2. Create VTPixelTransferSession
        var transferSession: VTPixelTransferSession?
        let status = VTPixelTransferSessionCreate(
            allocator: kCFAllocatorDefault,
            pixelTransferSessionOut: &transferSession
        )
        guard status == kCVReturnSuccess, let session = transferSession else {
            logger.error("Failed to create VTPixelTransferSession: \(status)")
            return nil
        }
        defer {
            VTPixelTransferSessionInvalidate(session)
        }

        // Set scaling mode to crop source to clean aperture
        VTSessionSetProperty(
            session,
            key: kVTPixelTransferPropertyKey_ScalingMode,
            value: kVTScalingMode_CropSourceToCleanAperture
        )

        // 3. Create destination buffer
        guard let dst = createNV12Buffer(width: dstWidth, height: dstHeight, format: format) else {
            return nil
        }

        // 4. Set CleanAperture to crop left half
        // Left eye offset: -width/4 (to center the left half)
        let horizontalOffset = CGFloat(dstWidth) * -0.5
        let cropRectDict: [CFString: Any] = [
            kCVImageBufferCleanApertureHorizontalOffsetKey: horizontalOffset,
            kCVImageBufferCleanApertureVerticalOffsetKey: 0,
            kCVImageBufferCleanApertureWidthKey: dstWidth,
            kCVImageBufferCleanApertureHeightKey: dstHeight
        ]
        CVBufferSetAttachment(
            sbs,
            kCVImageBufferCleanApertureKey,
            cropRectDict as CFDictionary,
            .shouldPropagate
        )

        // 5. Transfer image using VTPixelTransferSession
        let transferStatus = VTPixelTransferSessionTransferImage(session, from: sbs, to: dst)
        guard transferStatus == kCVReturnSuccess else {
            logger.error("VTPixelTransferSessionTransferImage failed: \(transferStatus)")
            return nil
        }

        return dst
    }

    // MARK: - 3단계: Stereo Mode (VTPixelTransfer + CleanAperture)

    /// Create stereo sample buffer from SBS pixel buffer using VTPixelTransferSession
    /// This is Apple's recommended approach (same as official sample)
    /// - Parameters:
    ///   - sbs: Source SBS pixel buffer (e.g., 1920×540)
    ///   - pts: Presentation timestamp
    ///   - duration: Frame duration
    /// - Returns: CMSampleBuffer with stereo tags for left/right eyes
    public func makeStereoSampleBuffer(
        from sbs: CVPixelBuffer,
        pts: CMTime,
        duration: CMTime
    ) -> CMSampleBuffer? {
        // 1. Validate
        guard validateSBSBuffer(sbs) else {
            return nil
        }

        let srcWidth = CVPixelBufferGetWidth(sbs)
        let srcHeight = CVPixelBufferGetHeight(sbs)
        let eyeWidth = srcWidth / 2
        let eyeHeight = srcHeight
        let format = CVPixelBufferGetPixelFormatType(sbs)

        // 2. Create VTPixelTransferSession (if not cached)
        var transferSession: VTPixelTransferSession?
        let status = VTPixelTransferSessionCreate(
            allocator: kCFAllocatorDefault,
            pixelTransferSessionOut: &transferSession
        )
        guard status == kCVReturnSuccess, let session = transferSession else {
            logger.error("Failed to create VTPixelTransferSession: \(status)")
            return nil
        }
        defer {
            VTPixelTransferSessionInvalidate(session)
        }

        // Set scaling mode to crop source to clean aperture
        VTSessionSetProperty(
            session,
            key: kVTPixelTransferPropertyKey_ScalingMode,
            value: kVTScalingMode_CropSourceToCleanAperture
        )

        // 3. Process left and right eyes
        var taggedBuffers = [CMTaggedDynamicBuffer]()

        for (layerID, eye) in [(0, CMStereoViewComponents.leftEye), (1, CMStereoViewComponents.rightEye)] {
            // Create destination buffer
            guard let dstBuffer = createNV12Buffer(width: eyeWidth, height: eyeHeight, format: format) else {
                logger.error("Failed to create buffer for \(eye == .leftEye ? "left" : "right") eye")
                return nil
            }

            // Set CleanAperture on source to crop to this eye
            let horizontalOffset = CGFloat(eyeWidth) * (CGFloat(layerID) - 0.5)
            let cropRectDict: [CFString: Any] = [
                kCVImageBufferCleanApertureHorizontalOffsetKey: horizontalOffset,
                kCVImageBufferCleanApertureVerticalOffsetKey: 0,
                kCVImageBufferCleanApertureWidthKey: eyeWidth,
                kCVImageBufferCleanApertureHeightKey: eyeHeight
            ]
            CVBufferSetAttachment(
                sbs,
                kCVImageBufferCleanApertureKey,
                cropRectDict as CFDictionary,
                .shouldPropagate
            )

            // Transfer image using VTPixelTransferSession
            let transferStatus = VTPixelTransferSessionTransferImage(session, from: sbs, to: dstBuffer)
            guard transferStatus == kCVReturnSuccess else {
                logger.error("VTPixelTransferSessionTransferImage failed for layer \(layerID): \(transferStatus)")
                return nil
            }

            // Create tagged buffer
            let tags: [CMTag] = [
                .videoLayerID(Int64(layerID)),
                .stereoView(eye),
                .mediaType(.video)
            ]
            taggedBuffers.append(
                CMTaggedDynamicBuffer(
                    tags: tags,
                    content: .pixelBuffer(CVReadOnlyPixelBuffer(unsafeBuffer: dstBuffer))
                )
            )
        }

        // 4. Create CMReadySampleBuffer
        let buffer = CMReadySampleBuffer(
            taggedBuffers: taggedBuffers,
            formatDescription: CMTaggedBufferGroupFormatDescription(taggedBuffers: taggedBuffers),
            presentationTimeStamp: pts,
            duration: duration
        )

        var outSB: CMSampleBuffer?
        buffer.withUnsafeSampleBuffer { sb in
            outSB = sb
        }

        // 5. Add stereo attachments
        if let sampleBuffer = outSB {
            addStereoAttachments(to: sampleBuffer)
        }

        return outSB
    }

    // MARK: - Validation

    /// Validate SBS pixel buffer format and dimensions
    private func validateSBSBuffer(_ sbs: CVPixelBuffer) -> Bool {
        let width = CVPixelBufferGetWidth(sbs)
        let height = CVPixelBufferGetHeight(sbs)
        let format = CVPixelBufferGetPixelFormatType(sbs)

        // Check width is even and >= 2
        guard width >= 2, width % 2 == 0 else {
            logger.error("Invalid SBS width: \(width). Must be even and >= 2")
            return false
        }

        // Check format is NV12
        guard format == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange ||
              format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange else {
            logger.error("Unsupported format: \(self.formatString(format)). Only NV12 supported")
            return false
        }

        return true
    }

    // MARK: - Buffer Creation

    /// Create NV12 pixel buffer
    private func createNV12Buffer(width: Int, height: Int, format: OSType) -> CVPixelBuffer? {
        let attrs: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: format,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
        ]

        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            format,
            attrs as CFDictionary,
            &buffer
        )

        guard status == kCVReturnSuccess, let result = buffer else {
            logger.error("Failed to create pixel buffer: \(status)")
            return nil
        }

        return result
    }

    // MARK: - Pixel Buffer Copying

    /// Copy left half of SBS buffer to destination (FIXED for NV12)
    private func copyLeftHalfFixed(from src: CVPixelBuffer, to dst: CVPixelBuffer) -> Bool {
        let srcWidth = CVPixelBufferGetWidth(src)
        let dstWidth = CVPixelBufferGetWidth(dst)
        let dstHeight = CVPixelBufferGetHeight(dst)

        CVPixelBufferLockBaseAddress(src, .readOnly)
        CVPixelBufferLockBaseAddress(dst, [])
        defer {
            CVPixelBufferUnlockBaseAddress(src, .readOnly)
            CVPixelBufferUnlockBaseAddress(dst, [])
        }

        // Debug: Check strides
        let srcYStride = CVPixelBufferGetBytesPerRowOfPlane(src, 0)
        let dstYStride = CVPixelBufferGetBytesPerRowOfPlane(dst, 0)
        let srcUVStride = CVPixelBufferGetBytesPerRowOfPlane(src, 1)
        let dstUVStride = CVPixelBufferGetBytesPerRowOfPlane(dst, 1)

        logger.debug("📐 Fixed copy - Src: \(srcWidth)×\(dstHeight), Y stride: \(srcYStride), UV stride: \(srcUVStride)")
        logger.debug("📐 Fixed copy - Dst: \(dstWidth)×\(dstHeight), Y stride: \(dstYStride), UV stride: \(dstUVStride)")

        // Copy Y plane (left half)
        guard let srcYBase = CVPixelBufferGetBaseAddressOfPlane(src, 0),
              let dstYBase = CVPixelBufferGetBaseAddressOfPlane(dst, 0) else {
            logger.error("Failed to get Y plane base addresses")
            return false
        }

        for row in 0..<dstHeight {
            let srcPtr = srcYBase + row * srcYStride
            let dstPtr = dstYBase + row * dstYStride
            memcpy(dstPtr, srcPtr, dstWidth)  // Copy dstWidth bytes (960)
        }

        // Copy UV plane (left half) - CRITICAL FIX!
        guard let srcUVBase = CVPixelBufferGetBaseAddressOfPlane(src, 1),
              let dstUVBase = CVPixelBufferGetBaseAddressOfPlane(dst, 1) else {
            logger.error("Failed to get UV plane base addresses")
            return false
        }

        let uvHeight = dstHeight / 2  // UV plane is half resolution vertically

        // NV12 UV plane analysis:
        // - Source SBS: 1920×540 → UV plane: 960 samples × 270 rows → 1920 bytes/row (U,V interleaved)
        // - Dest (left half): 960×540 → UV plane: 480 samples × 270 rows → 960 bytes/row
        // - We copy left 480 samples = 960 bytes from each source row

        // WAIT! Let's check actual strides from debug log:
        // Src UV stride: 2176 (with padding)
        // Dst UV stride: 960 (no padding)
        // We want left half of UV samples = dstWidth bytes
        let uvBytesPerRow = dstWidth  // 960 bytes (left 480 UV samples × 2 bytes each)

        logger.debug("📐 UV copy: height=\(uvHeight), bytesPerRow=\(uvBytesPerRow)")

        for row in 0..<uvHeight {
            let srcPtr = srcUVBase + row * srcUVStride
            let dstPtr = dstUVBase + row * dstUVStride
            memcpy(dstPtr, srcPtr, uvBytesPerRow)
        }

        return true
    }

    /// Copy left half of SBS buffer to destination (OLD - DO NOT USE)
    private func copyLeftHalf(from src: CVPixelBuffer, to dst: CVPixelBuffer) -> Bool {
        let srcWidth = CVPixelBufferGetWidth(src)
        let dstWidth = CVPixelBufferGetWidth(dst)
        let dstHeight = CVPixelBufferGetHeight(dst)

        CVPixelBufferLockBaseAddress(src, .readOnly)
        CVPixelBufferLockBaseAddress(dst, [])
        defer {
            CVPixelBufferUnlockBaseAddress(src, .readOnly)
            CVPixelBufferUnlockBaseAddress(dst, [])
        }

        // Debug: Check strides
        let srcYStride = CVPixelBufferGetBytesPerRowOfPlane(src, 0)
        let dstYStride = CVPixelBufferGetBytesPerRowOfPlane(dst, 0)
        let srcUVStride = CVPixelBufferGetBytesPerRowOfPlane(src, 1)
        let dstUVStride = CVPixelBufferGetBytesPerRowOfPlane(dst, 1)

        logger.debug("📐 Buffer info - Src: \(srcWidth)×\(dstHeight), Y stride: \(srcYStride), UV stride: \(srcUVStride)")
        logger.debug("📐 Buffer info - Dst: \(dstWidth)×\(dstHeight), Y stride: \(dstYStride), UV stride: \(dstUVStride)")

        // Copy Y plane (left half)
        guard copyYPlaneLeftHalf(from: src, to: dst, width: dstWidth, height: dstHeight) else {
            return false
        }

        // Copy UV plane (left half)
        guard copyUVPlaneLeftHalf(from: src, to: dst, width: dstWidth, height: dstHeight) else {
            return false
        }

        return true
    }

    /// Copy Y plane (left half only)
    private func copyYPlaneLeftHalf(
        from src: CVPixelBuffer,
        to dst: CVPixelBuffer,
        width: Int,
        height: Int
    ) -> Bool {
        guard let srcBase = CVPixelBufferGetBaseAddressOfPlane(src, 0),
              let dstBase = CVPixelBufferGetBaseAddressOfPlane(dst, 0) else {
            logger.error("Failed to get Y plane base addresses")
            return false
        }

        let srcStride = CVPixelBufferGetBytesPerRowOfPlane(src, 0)
        let dstStride = CVPixelBufferGetBytesPerRowOfPlane(dst, 0)

        for row in 0..<height {
            let srcPtr = srcBase + row * srcStride  // Start from left (offset 0)
            let dstPtr = dstBase + row * dstStride
            memcpy(dstPtr, srcPtr, width)
        }

        return true
    }

    /// Copy UV plane (left half only)
    private func copyUVPlaneLeftHalf(
        from src: CVPixelBuffer,
        to dst: CVPixelBuffer,
        width: Int,
        height: Int
    ) -> Bool {
        guard let srcBase = CVPixelBufferGetBaseAddressOfPlane(src, 1),
              let dstBase = CVPixelBufferGetBaseAddressOfPlane(dst, 1) else {
            logger.error("Failed to get UV plane base addresses")
            return false
        }

        let srcStride = CVPixelBufferGetBytesPerRowOfPlane(src, 1)
        let dstStride = CVPixelBufferGetBytesPerRowOfPlane(dst, 1)
        let uvHeight = height / 2  // UV plane is half resolution

        // NV12: UV is 4:2:0 subsampled, so width in bytes = Y width
        // Each UV sample covers 2x2 Y pixels, stored as interleaved UV pairs
        let uvBytesPerRow = width  // Same as Y width in bytes

        for row in 0..<uvHeight {
            let srcPtr = srcBase + row * srcStride  // Start from left (offset 0)
            let dstPtr = dstBase + row * dstStride
            memcpy(dstPtr, srcPtr, uvBytesPerRow)
        }

        return true
    }

    /// Copy region of pixel buffer (with x offset)
    private func copyRegion(
        from src: CVPixelBuffer,
        to dst: CVPixelBuffer,
        xOffset: Int,
        width: Int,
        height: Int
    ) -> Bool {
        CVPixelBufferLockBaseAddress(src, .readOnly)
        CVPixelBufferLockBaseAddress(dst, [])
        defer {
            CVPixelBufferUnlockBaseAddress(src, .readOnly)
            CVPixelBufferUnlockBaseAddress(dst, [])
        }

        // Copy Y plane
        guard copyYPlaneRegion(from: src, to: dst, xOffset: xOffset, width: width, height: height) else {
            return false
        }

        // Copy UV plane
        guard copyUVPlaneRegion(from: src, to: dst, xOffset: xOffset, width: width, height: height) else {
            return false
        }

        return true
    }

    /// Copy Y plane region
    private func copyYPlaneRegion(
        from src: CVPixelBuffer,
        to dst: CVPixelBuffer,
        xOffset: Int,
        width: Int,
        height: Int
    ) -> Bool {
        guard let srcBase = CVPixelBufferGetBaseAddressOfPlane(src, 0),
              let dstBase = CVPixelBufferGetBaseAddressOfPlane(dst, 0) else {
            logger.error("Failed to get Y plane base addresses")
            return false
        }

        let srcStride = CVPixelBufferGetBytesPerRowOfPlane(src, 0)
        let dstStride = CVPixelBufferGetBytesPerRowOfPlane(dst, 0)

        for row in 0..<height {
            let srcPtr = srcBase + row * srcStride + xOffset
            let dstPtr = dstBase + row * dstStride
            memcpy(dstPtr, srcPtr, width)
        }

        return true
    }

    /// Copy UV plane region (FIXED for NV12 4:2:0)
    private func copyUVPlaneRegion(
        from src: CVPixelBuffer,
        to dst: CVPixelBuffer,
        xOffset: Int,
        width: Int,
        height: Int
    ) -> Bool {
        guard let srcBase = CVPixelBufferGetBaseAddressOfPlane(src, 1),
              let dstBase = CVPixelBufferGetBaseAddressOfPlane(dst, 1) else {
            logger.error("Failed to get UV plane base addresses")
            return false
        }

        let srcStride = CVPixelBufferGetBytesPerRowOfPlane(src, 1)
        let dstStride = CVPixelBufferGetBytesPerRowOfPlane(dst, 1)
        let uvHeight = height / 2  // UV is half height

        // NV12 4:2:0: UV plane is subsampled 2x in both dimensions
        let uvXOffset = xOffset / 2  // Half of Y offset
        let uvBytesPerRow = width / 2  // Half of Y width

        for row in 0..<uvHeight {
            let srcPtr = srcBase + row * srcStride + uvXOffset
            let dstPtr = dstBase + row * dstStride
            memcpy(dstPtr, srcPtr, uvBytesPerRow)
        }

        return true
    }

    // MARK: - Stereo Processing

    private enum Eye {
        case left
        case right
    }

    /// Split one eye from SBS pixel buffer
    private func splitEye(from sbs: CVPixelBuffer, eye: Eye) -> CVPixelBuffer? {
        let srcWidth = CVPixelBufferGetWidth(sbs)
        let srcHeight = CVPixelBufferGetHeight(sbs)
        let format = CVPixelBufferGetPixelFormatType(sbs)

        let eyeWidth = srcWidth / 2
        let eyeHeight = srcHeight
        let xOffset = (eye == .left) ? 0 : eyeWidth

        // Create destination buffer
        guard let dst = createNV12Buffer(width: eyeWidth, height: eyeHeight, format: format) else {
            return nil
        }

        // Copy region (will be fixed after Split SBS works)
        guard copyRegion(from: sbs, to: dst, xOffset: xOffset, width: eyeWidth, height: eyeHeight) else {
            logger.error("Failed to copy eye region")
            return nil
        }

        return dst
    }

    /// Create tagged buffers for left and right eyes
    private func createTaggedBuffers(
        left: CVPixelBuffer,
        right: CVPixelBuffer
    ) -> [CMTaggedDynamicBuffer] {
        let leftTags: [CMTag] = [
            .videoLayerID(0),
            .stereoView(.leftEye),
            .mediaType(.video)
        ]

        let rightTags: [CMTag] = [
            .videoLayerID(1),
            .stereoView(.rightEye),
            .mediaType(.video)
        ]

        return [
            CMTaggedDynamicBuffer(tags: leftTags, content: .pixelBuffer(CVReadOnlyPixelBuffer(unsafeBuffer: left))),
            CMTaggedDynamicBuffer(tags: rightTags, content: .pixelBuffer(CVReadOnlyPixelBuffer(unsafeBuffer: right)))
        ]
    }

    /// Create sample buffer from tagged buffers
    private func createSampleBuffer(
        from taggedBuffers: [CMTaggedDynamicBuffer],
        pts: CMTime,
        duration: CMTime
    ) -> CMSampleBuffer? {
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

        return outSB
    }

    /// Add stereo attachments to sample buffer
    private func addStereoAttachments(to sampleBuffer: CMSampleBuffer) {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(
            sampleBuffer,
            createIfNecessary: true
        ) else {
            return
        }

        let arr = attachments as NSArray
        if let dict = arr.firstObject as? NSMutableDictionary {
            dict[kCMSampleAttachmentKey_DisplayImmediately] = true
            dict[kCMSampleAttachmentKey_DoNotDisplay] = false
        }

        // Add HeroEye attachment (Left eye is hero)
        CMSetAttachment(
            sampleBuffer as CMAttachmentBearer,
            key: kCMFormatDescriptionExtension_HeroEye as CFString,
            value: kCMFormatDescriptionHeroEye_Left as CFTypeRef,
            attachmentMode: kCMAttachmentMode_ShouldPropagate
        )
    }

    // MARK: - Utilities

    private func formatString(_ format: OSType) -> String {
        let chars: [UInt8] = [
            UInt8((format >> 24) & 0xFF),
            UInt8((format >> 16) & 0xFF),
            UInt8((format >> 8) & 0xFF),
            UInt8(format & 0xFF)
        ]
        return String(bytes: chars, encoding: .ascii) ?? "????"
    }

}
