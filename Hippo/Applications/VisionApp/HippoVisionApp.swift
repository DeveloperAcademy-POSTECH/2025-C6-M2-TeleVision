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

    var body: some Scene {
        WindowGroup(id: WindowIDs.home) {
            RootView()
                .environment(appModel)
                .frame(minWidth: 580, maxWidth: 1020, minHeight: 760, maxHeight: 1020)
        }
        .windowResizability(.contentSize)

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
            guard let homeWindow = context.windows.first(where: { $0.id == WindowIDs.home }) else { return WindowPlacement() }
            return WindowPlacement(.trailing(homeWindow))
        }

        ImmersiveSpace(id: ImmersiveIDs.surgery, for: OperationContext.self)  { $context in
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
