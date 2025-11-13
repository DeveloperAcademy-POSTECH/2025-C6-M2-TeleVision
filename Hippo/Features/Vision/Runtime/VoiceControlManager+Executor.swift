//
//  VoiceControlManager+Executor.swift
//  Hippo
//

import Foundation

extension VoiceControlManager: VoiceCommandExecutor {

    public func execute(_ intent: VoiceCommandIntent) async throws {
        switch intent {
        case .hideUI:
            closeHeadController()

        case .showUI:
            openHeadController()

        case .closePanel:
            closeEndoscopicView()

        case .showVideoOnly:
            closeHeadController()
            openEndoscopicView()

        case let .rotateEntity(direction, angle):
            try await runtime.rotateSelectedEntity(direction: direction, angle: angle)

        case .unknown:
            throw VoiceControlError.noIntent
        }
    }
}
