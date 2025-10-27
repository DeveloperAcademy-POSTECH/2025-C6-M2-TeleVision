//
//  HeadPose.swift
//  Hippo
//
//  Created by yunsly on 10/26/25.
//

import SwiftUI
import RealityKit
import ARKit

@MainActor
@Observable
class HeadPose {
    
    // Singleton
    static let instance = HeadPose()
    private init() { }
    
    var transform: simd_float4x4 { ARSessionController.shared.deviceTransform }
    var position: SIMD3<Float> {
        .init(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }
    
    // 전방 방향
    var forward: SIMD3<Float> {
        let z = SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
        return -simd_normalize(z)
    }
}
