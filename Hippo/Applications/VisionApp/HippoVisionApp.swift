//
//  HippoVisionApp.swift
//  Hippo
//
//  Created by 김현기 on 10/13/25.
//

import SwiftUI

@main
struct HippoVisionApp: App {
    @State private var appModel = AppModel()
    @State private var homeViewModel = HomeViewModel()
    
    // Immersive Space 내에서 필요한 모델
    @State private var runtime = ImmersiveSceneRuntime()
    @State private var immersiveViewModel = ImmersiveViewModel()
    

    var body: some Scene {
        // 홈 화면
        WindowGroup(id: WindowIDs.home) {
            RootView()
                .environment(appModel)
                .environment(homeViewModel)
                .frame(minWidth: 580, maxWidth: 1020, minHeight: 760, maxHeight: 1020)
        }
        .windowResizability(.contentSize)

        // 환자 상세 화면
        WindowGroup(id: WindowIDs.patientDetail, for: String.self) { $id in
            if let id = id {
                PatientDetailView(patientId: id)
                    .environment(appModel)
                    .environment(homeViewModel)
            }
        }
        .windowResizability(.contentSize)

        // 수술 상세 화면
        WindowGroup(id: WindowIDs.operationDetail, for: OperationContext.self) { $context in
            if let context = context {
                OperationDetailView(
                    patientID: context.patientID,
                    operationID: context.operationID
                )
                .environment(appModel)
            }
        }
        .defaultSize(width: 480, height: appModel.homeWindowSize.height)
        .defaultWindowPlacement { _, context in
            // 1. 환자 상세 창이 열려있는지 확인
            if let patientDetailWindow = context.windows.first(where: { $0.id == WindowIDs.patientDetail }) {
                return WindowPlacement(.trailing(patientDetailWindow))
            }

            // 2. 환자 상세 창이 없으면 홈 창 옆에 배치
            if let homeWindow = context.windows.first(where: { $0.id == WindowIDs.home }) {
                return WindowPlacement(.trailing(homeWindow))
            }

            // 3. 둘 다 없으면 기본 배치
            return WindowPlacement()
        }

        // MARK: -- 수술 시작 후
        
        // 몰입형 수술 화면
        ImmersiveSpace(id: ImmersiveIDs.surgery, for: OperationContext.self) { $context in
            if let context = context {
                ImmersiveSurgeryView(
                    patientID: context.patientID,
                    operationID: context.operationID
                )
                .environment(appModel)
            }
        }

    }
}
