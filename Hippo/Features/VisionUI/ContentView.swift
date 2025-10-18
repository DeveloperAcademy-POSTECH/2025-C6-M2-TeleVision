//
//  ContentView.swift
//  TeleVision
//
//  Created by 김현기 on 10/13/25.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack {
            Model3D(named: "Scene", bundle: realityKitContentBundle)
                .padding(.bottom, 50)

            Text("Hello, world!")
            
            ToggleImmersiveSpaceButton()

            Button("Open Patients") {
                openWindow(id: "patients")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
