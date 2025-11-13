//
//  ImmersiveSceneRuntime+VoiceControl.swift
//  Hippo
//
//  Voice Control support for ImmersiveSceneRuntime
//

import Foundation
import RealityKit

extension ImmersiveSceneRuntime {

    /// Rotate the currently selected entity
    ///
    /// - Parameters:
    ///   - direction: Rotation direction (left, right, up, down)
    ///   - angle: Rotation angle in degrees (5~180)
    /// - Throws: VoiceControlError
    func rotateSelectedEntity(direction: RotationDirection, angle: Double) async throws {
        guard let entity = selectedEntity else {
            throw VoiceControlError.noSelectedEntity
        }

        guard angle >= 5 && angle <= 180 else {
            throw VoiceControlError.invalidParameters("Angle must be between 5° and 180°")
        }

        let radians = Float(angle * .pi / 180)

        let axis: SIMD3<Float>
        switch direction {
        case .left: axis = [0, 1, 0]
        case .right: axis = [0, -1, 0]
        case .up: axis = [1, 0, 0]
        case .down: axis = [-1, 0, 0]
        }

        let rotation = simd_quatf(angle: radians, axis: axis)
        let newOrientation = simd_mul(rotation, entity.orientation(relativeTo: nil))
        entity.setOrientation(newOrientation, relativeTo: nil)
    }
}
