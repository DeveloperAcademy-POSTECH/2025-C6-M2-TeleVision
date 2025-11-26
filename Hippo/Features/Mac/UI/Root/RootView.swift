//
//  ContentView.swift
//  HippoMac
//
//  Deprecated: Use PatientView instead
//

import SwiftUI

enum Tabs {
    case Home
    case StreamingControl
}

struct RootView: View {
    @State private var selectedTab: Tabs = .Home

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.hippoBackground).ignoresSafeArea()

                // Keep both views alive, show/hide with opacity
                // This prevents StreamingControlView from being recreated on tab switch
                HomeView()
                    .opacity(selectedTab == .Home ? 1 : 0)
                    .allowsHitTesting(selectedTab == .Home)

                StreamingControlView()
                    .opacity(selectedTab == .StreamingControl ? 1 : 0)
                    .allowsHitTesting(selectedTab == .StreamingControl)

                VStack {
                    HStack {
                        Spacer()
                        TabPicker(selectedTab: $selectedTab)
                            .padding()
                    }
                    Spacer()
                }
            }
        }
        .preferredColorScheme(.light)
    }
}

#Preview {
    RootView()
}
