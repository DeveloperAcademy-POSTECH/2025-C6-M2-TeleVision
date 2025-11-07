//
//  RightCaptureSession.swift
//  Hippo
//
//  Right camera capture session
//

import Foundation

/// Right camera capture session
/// Inherits all functionality from BaseCaptureSession
public final class RightCaptureSession: BaseCaptureSession {

    public init(preferredDeviceUniqueID: String? = nil) {
        super.init(source: .right, preferredDeviceUniqueID: preferredDeviceUniqueID)
    }
}
