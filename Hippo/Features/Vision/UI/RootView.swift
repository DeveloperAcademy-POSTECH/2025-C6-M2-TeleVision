//
//  RootView.swift
//  Hippo
//
//  Created by eunsong on 10/22/25.
//

import Dependencies
import SwiftUI

struct RootView: View {
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        HomeView()
            .withVisionDependencies(
                open: { await openImmersiveSpace(id: ImmersiveIDs.surgery) },
                close: { await dismissImmersiveSpace() }
            )
    }
}
