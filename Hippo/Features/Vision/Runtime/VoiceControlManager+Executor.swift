//
//  VoiceControlManager+Executor.swift
//  Hippo
//

import Foundation

extension VoiceControlManager: VoiceCommandExecutor {

    public func execute(_ intent: VoiceCommandIntent) async throws {
        switch intent {
        case .closeMenu:
            closeHeadController()

        case .openMenu:
            openHeadController()

        case .closeVideo:
            closeEndoscopicView()

        case .showVideo:
            openEndoscopicView()

        case let .rotateEntity(direction, angle):
            try await runtime.rotateSelectedEntity(direction: direction, angle: angle)

        case .unknown:
            throw VoiceControlError.noIntent
        }
    }
}
