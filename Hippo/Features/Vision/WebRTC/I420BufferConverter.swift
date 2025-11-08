//
//  I420BufferConverter.swift
//  Hippo
//
//  Converts LKRTCI420Buffer to CVPixelBuffer for WebRTC video frames
//

import Foundation
import CoreVideo
import LiveKitWebRTC
import os.log

/// Converts I420 (planar YUV 4:2:0) buffers to NV12 CVPixelBuffer format
/// I420 format: Y plane (full res) + U plane (half res) + V plane (half res)
/// NV12 format: Y plane (full res) + interleaved UV plane (half res)
actor I420BufferConverter {

    private let logger = Logger(subsystem: "com.television.hippo", category: "I420Converter")

    init() {
        logger.info("✅ I420BufferConverter initialized")
    }

    /// Convert I420Buffer to CVPixelBuffer (NV12 format)
    /// - Parameter i420Buffer: Source I420 buffer from WebRTC
    /// - Returns: CVPixelBuffer in NV12 format, or nil if conversion fails
    func convert(_ i420Buffer: LKRTCI420Buffer) -> CVPixelBuffer? {
        let width = Int(i420Buffer.width)
        let height = Int(i420Buffer.height)

        // Create NV12 pixel buffer (more efficient for GPU operations)
        let attrs: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let pb = pixelBuffer else {
            logger.error("❌ Failed to create CVPixelBuffer for I420 conversion: \(status)")
            return nil
        }

        // Lock pixel buffer for writing
        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }

        // Get destination plane pointers for NV12 (Y plane + UV interleaved plane)
        guard let yDest = CVPixelBufferGetBaseAddressOfPlane(pb, 0),
              let uvDest = CVPixelBufferGetBaseAddressOfPlane(pb, 1) else {
            logger.error("❌ Failed to get plane addresses")
            return nil
        }

        let yDestStride = CVPixelBufferGetBytesPerRowOfPlane(pb, 0)
        let uvDestStride = CVPixelBufferGetBytesPerRowOfPlane(pb, 1)

        // Get I420 source pointers
        let ySrc = i420Buffer.dataY
        let uSrc = i420Buffer.dataU
        let vSrc = i420Buffer.dataV
        let ySrcStride = Int(i420Buffer.strideY)
        let uSrcStride = Int(i420Buffer.strideU)
        let vSrcStride = Int(i420Buffer.strideV)

        // Copy Y plane (full resolution)
        for y in 0..<height {
            let srcOffset = y * ySrcStride
            let dstOffset = y * yDestStride
            memcpy(yDest.advanced(by: dstOffset), ySrc.advanced(by: srcOffset), width)
        }

        // Convert U and V planes to interleaved UV for NV12 (half resolution)
        let uvHeight = height / 2
        let uvWidth = width / 2

        for y in 0..<uvHeight {
            let uSrcOffset = y * uSrcStride
            let vSrcOffset = y * vSrcStride
            let uvDstOffset = y * uvDestStride

            for x in 0..<uvWidth {
                let uvDstPtr = uvDest.advanced(by: uvDstOffset + x * 2)
                let uValue = uSrc.advanced(by: uSrcOffset + x).pointee
                let vValue = vSrc.advanced(by: vSrcOffset + x).pointee

                // NV12 format: U and V interleaved
                uvDstPtr.storeBytes(of: uValue, as: UInt8.self)
                uvDstPtr.advanced(by: 1).storeBytes(of: vValue, as: UInt8.self)
            }
        }

        logger.debug("✅ I420 → NV12 conversion complete: \(width)×\(height)")
        return pb
    }
}
