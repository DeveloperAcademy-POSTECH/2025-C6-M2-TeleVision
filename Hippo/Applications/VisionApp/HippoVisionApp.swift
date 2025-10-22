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
        WindowGroup(id: "InitialWindow") {
            HomeView()
                .frame(minWidth: 580, maxWidth: 1020, minHeight: 760, maxHeight: 1020)
                .environment(appModel)
        }
        .windowResizability(.contentSize)

        WindowGroup(id: "OperationDetailWindow") {
            OperationDetailView()
                .environment(appModel)
        }
        
    }
}
