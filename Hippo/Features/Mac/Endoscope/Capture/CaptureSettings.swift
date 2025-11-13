//
//  CaptureSettings.swift
//  Hippo
//
//  Camera capture settings for UVC cameras
//

import Foundation
import AVFoundation
import os.log

/// Capture settings for camera configuration
public struct CaptureSettings {
    /// Target resolution
    public let width: Int
    public let height: Int

    /// Target frame rate (fps)
    public let frameRate: Int

    /// Pixel format
    public let pixelFormat: OSType

    /// Standard 1080p60 settings for endoscope cameras
    public static let standard = CaptureSettings(
        width: 1920,
        height: 1080,
        frameRate: 60,
        pixelFormat: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange  // NV12
    )

    /// 1080p30 for lower bandwidth
    public static let lowBandwidth = CaptureSettings(
        width: 1920,
        height: 1080,
        frameRate: 30,
        pixelFormat: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
    )

    /// 720p60 for testing
    public static let test720p = CaptureSettings(
        width: 1280,
        height: 720,
        frameRate: 60,
        pixelFormat: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
    )

    public init(width: Int, height: Int, frameRate: Int, pixelFormat: OSType) {
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.pixelFormat = pixelFormat
    }

    /// Finds the common maximum FPS supported by multiple devices
    /// - Parameters:
    ///   - devices: Array of capture devices
    ///   - width: Target width
    ///   - height: Target height
    ///   - pixelFormat: Target pixel format
    /// - Returns: CaptureSettings with the common max FPS, or nil if no common format
    public static func findCommonSettings(
        for devices: [AVCaptureDevice],
        width: Int = 1920,
        height: Int = 1080,
        pixelFormat: OSType = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
    ) -> CaptureSettings? {
        let logger = Logger(subsystem: "com.television.hippo", category: "CaptureSettings")

        guard !devices.isEmpty else {
            logger.error("❌ No devices provided")
            return nil
        }

        // Find max FPS for each device
        var deviceMaxFPS: [String: Double] = [:]

        for device in devices {
            // Find format matching resolution and pixel format
            let matchingFormat = device.formats.first { format in
                let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                let fmt = CMFormatDescriptionGetMediaSubType(format.formatDescription)

                return dimensions.width == width &&
                       dimensions.height == height &&
                       fmt == pixelFormat
            }

            guard let format = matchingFormat else {
                logger.warning("⚠️ Device '\(device.localizedName)' doesn't support \(width)×\(height)")
                continue
            }

            // Get max FPS from supported frame rate ranges
            let maxFPS = format.videoSupportedFrameRateRanges
                .map { 1.0 / CMTimeGetSeconds($0.minFrameDuration) }
                .max() ?? 0.0

            deviceMaxFPS[device.localizedName] = maxFPS
            logger.info("📹 '\(device.localizedName)' max FPS: \(String(format: "%.0f", maxFPS))")
        }

        // Find common minimum (the lowest max FPS among all devices)
        guard let commonMaxFPS = deviceMaxFPS.values.min() else {
            logger.error("❌ Could not determine common FPS")
            return nil
        }

        // Round down to common values (60, 30, 24, 15, etc.)
        let standardFPS: [Int] = [60, 30, 24, 15]
        let selectedFPS = standardFPS.first { Double($0) <= commonMaxFPS } ?? 30

        logger.info("✅ Common max FPS: \(String(format: "%.0f", commonMaxFPS)) → using \(selectedFPS) fps")

        return CaptureSettings(
            width: width,
            height: height,
            frameRate: selectedFPS,
            pixelFormat: pixelFormat
        )
    }
}
