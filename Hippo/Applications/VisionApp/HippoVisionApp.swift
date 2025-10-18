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
            PatientListView()
                .environment(appModel)
        }
    }
}
