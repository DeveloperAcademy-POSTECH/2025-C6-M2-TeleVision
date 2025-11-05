//
//  HippoMacApp.swift
//  HippoMac
//
//  Created by eunsong on 10/16/25.
//

import SwiftUI

@main
struct HippoMacApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
                .frame(minWidth: 1024, maxWidth: .infinity, minHeight: 576, maxHeight: .infinity)
        }
    }
}


