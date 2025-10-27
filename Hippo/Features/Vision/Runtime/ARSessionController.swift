//
//  ARSessionController.swift
//  Hippo
//
//  Created by yunsly on 10/26/25.
//

import Foundation
import SwiftUI
import ARKit

@MainActor
@Observable
final class ARSessionController {
    static let shared = ARSessionController()
    
    // 외부 접근 방지
    private init() { }
    private(set) var session: ARKitSession?
    private var worldTracking: WorldTrackingProvider?
    
    var deviceTransform = matrix_identity_float4x4
    private var timer: Timer?
    
    // MARK: -- run / stop ARSession
    
    func runARSession() {
        guard session == nil else { return }
        if timer != nil { return }
        
        let session = ARKitSession()
        let world = worldTracking ?? WorldTrackingProvider()
        
        self.session = session
        self.worldTracking = world
        
        Task {
            try? await session.run([world])
        }
        
        // 디바이스 위치 0.1초 간격으로 업데이트
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task.detached {
                let now = CACurrentMediaTime()
                if let dev = await self.worldTracking?.queryDeviceAnchor(atTimestamp: now) {
                    let t = dev.originFromAnchorTransform
                    await MainActor.run { self.deviceTransform = t }
                }
            }
        }
    }
    
    func stopARSession() {
        guard session != nil else { return }
        if timer == nil { return }
        
        timer?.invalidate()
        timer = nil
        Task { [session] in
            if let session = session {
                session.stop()
            }
            self.session = nil
        }
    }
    
    
}
