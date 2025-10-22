import RealityKit
import SwiftUI

struct ImmersiveView: View {
    @StateObject private var runtime = ImmersiveSceneRuntime()

    var body: some View {
        RealityView { content in
            runtime.setupScene(in: content)
        }
        .onAppear { runtime.start() }
        .onDisappear { runtime.stop() }
    }
}
