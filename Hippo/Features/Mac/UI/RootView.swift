//
//  ContentView.swift
//  HippoMac
//
//  Deprecated: Use PatientView instead
//

import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab {
                HomeView()
            } label: {
                Text("Patients")
            }
            Tab {
                StreamingControlView()
            } label: {
                Text("Camera")
            }
        }
    }
}

#Preview {
    RootView()
}
