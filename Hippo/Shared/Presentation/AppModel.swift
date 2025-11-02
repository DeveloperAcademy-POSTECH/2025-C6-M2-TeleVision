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

    // MARK: - State

    public var patients: Int = 0
    public var operations: Int = 0

    // MARK: - Home Window Size

    public var homeWindowSize: CGSize = .init(width: 580, height: 760)

    public func updateHomeWindowSize(_ size: CGSize) {
        homeWindowSize = size
        logger.debug("🐛 Updated home window size to \(size.width)x\(size.height)")
    }

    // MARK: - OperationDetailWindow

    // 현재 열려있는 OperationDetail 윈도우의 컨텍스트
    public var currentOperationContext: OperationContext?

    // OperationDetail 윈도우 열기 (기존 윈도우 닫기 포함)
    public func openOperationDetail(
        context: OperationContext,
        openWindow: OpenWindowAction,
        dismissWindow: DismissWindowAction
    ) {
        // 1. 기존 윈도우가 열려있으면 닫기
        if currentOperationContext != nil {
            dismissWindow(id: WindowIDs.operationDetail)
        }

        // 2. 새 윈도우 열기
        openWindow(id: WindowIDs.operationDetail, value: context)

        // 3. 현재 컨텍스트 업데이트
        currentOperationContext = context
    }
}
