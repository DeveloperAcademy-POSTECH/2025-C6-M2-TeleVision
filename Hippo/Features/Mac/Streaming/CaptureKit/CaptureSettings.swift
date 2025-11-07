//
//  CaptureSettings.swift
//  Hippo
//
//  Camera capture settings for UVC cameras
//

import Foundation
import AVFoundation

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
}
