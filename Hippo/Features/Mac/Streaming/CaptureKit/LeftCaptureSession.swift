//
//  LeftCaptureSession.swift
//  Hippo
//
//  Left camera capture session
//

import Foundation

/// Left camera capture session
/// Inherits all functionality from BaseCaptureSession
public final class LeftCaptureSession: BaseCaptureSession {

    public init(preferredDeviceUniqueID: String? = nil) {
        super.init(source: .left, preferredDeviceUniqueID: preferredDeviceUniqueID)
    }
}
