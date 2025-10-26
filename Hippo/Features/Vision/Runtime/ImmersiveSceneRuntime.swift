import Combine
import RealityKit
import SwiftUI

@MainActor
final class ImmersiveSceneRuntime: ObservableObject {

    // RealityView 의 content 관리
    func setupScene(in content: RealityViewContent) {
        // RealityViewContent 는 RealityView 의 클로저 파라미터입니다.
        // 여기서 scene을 직접 new 하는 게 아니라, AnchorEntity를 추가해야 해요.
        let anchor = AnchorEntity(world: .zero)

        // 테스트용 엔티티
        let sphere = ModelEntity(mesh: .generateSphere(radius: 0.1))
        sphere.position = [0, 1, -1]
        anchor.addChild(sphere)

        // RealityViewContent에 엔티티 추가
        content.add(anchor)
    }

    func start() {
        print("ImmersiveSceneRuntime started")
        
        // TODO: 추후 Entity 조작모드가 on 될 때만 작동하도록 수정할 것
        ARSessionController.shared.runARSession()
    }

    func stop() {
        print("ImmersiveSceneRuntime stopped")
        
        // TODO: 추후 Entity 조작모드 off 될 때만 작동하도록 수정할 것
        ARSessionController.shared.stopARSession()
    }
}
