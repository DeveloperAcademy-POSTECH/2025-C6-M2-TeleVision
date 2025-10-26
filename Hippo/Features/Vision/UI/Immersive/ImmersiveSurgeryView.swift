//
//  ImmersiveSurgeryView.swift
//  HippoVision
//
//  Created by 김현기 on 10/24/25.
//

import RealityKit
import SwiftUI

struct ImmersiveSurgeryView: View {
    @StateObject private var runtime = ImmersiveSceneRuntime()

    var body: some View {
        RealityView { content in
            runtime.setupScene(in: content)
        }
        .onAppear { runtime.start() }
        .onDisappear { runtime.stop() }
    }
}

#Preview {
    ImmersiveSurgeryView()
}
