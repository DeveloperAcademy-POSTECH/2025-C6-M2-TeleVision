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
                .toolbar(removing: .title)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
                .frame(minWidth: 600, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
        }
    }
}
