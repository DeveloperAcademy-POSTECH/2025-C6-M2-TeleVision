//
//  RootView.swift
//  Hippo
//
//  Created by eunsong on 10/22/25.
//

import SwiftUI

struct RootView: View {
    var body: some View {
        HomeView()
            .environment(\.entityLocator, RealityEntityLocator())
            .environment(\.anchorService, RealityAnchorService())
    }
}
