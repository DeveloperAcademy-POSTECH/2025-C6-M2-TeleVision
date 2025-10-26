//
//  AppModel.swift
//  TeleVision
//
//  Created by 김현기 on 10/13/25.
//

import os.log
import SwiftUI

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    // MARK: - Logger

    private let logger = Logger(subsystem: "com.television.hippo", category: "PatientViewModel")

    public init() {}

    // MARK: - Home Window Size

    public var homeWindowSize: CGSize = .init(width: 580, height: 760)

    public func updateHomeWindowSize(_ size: CGSize) {
        homeWindowSize = size
        logger.debug("🐛 Updated home window size to \(size.width)x\(size.height)")
    }
}
