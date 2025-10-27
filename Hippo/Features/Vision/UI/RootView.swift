//
//  RootView.swift
//  Hippo
//
//  Created by eunsong on 10/22/25.
//

import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        GeometryReader { geometry in
            HomeView()
                .onAppear {
                    appModel.updateHomeWindowSize(geometry.size)
                }
                .onChange(of: geometry.size) {
                    appModel.updateHomeWindowSize(geometry.size)
                }
//                .environment(\.entityLocator, RealityEntityLocator())
//                .environment(\.anchorService, RealityAnchorService())
        }
    }
}
