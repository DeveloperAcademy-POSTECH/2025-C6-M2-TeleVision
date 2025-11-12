//
//  CaptureOutputDelegate.swift
//  Hippo
//
//  Delegate protocol for capture frame callbacks
//

import Foundation
import CoreVideo
import CoreMedia

/// Delegate for capture session frame output
public protocol CaptureOutputDelegate: AnyObject {
    /// Called when a new frame is captured
    /// - Parameters:
    ///   - pixelBuffer: Captured frame
    ///   - pts: Presentation timestamp
    ///   - source: Camera source (left/right)
    func didOutput(pixelBuffer: CVPixelBuffer, pts: CMTime, source: CaptureSource)

    /// Called when capture encounters an error
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - source: Camera source (left/right)
    func didEncounterError(_ error: Error, source: CaptureSource)
}

/// Default implementation for optional methods
public extension CaptureOutputDelegate {
    func didEncounterError(_ error: Error, source: CaptureSource) {
        // Default: do nothing
    }
}
