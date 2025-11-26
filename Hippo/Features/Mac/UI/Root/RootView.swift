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
                // 메인 컨텐츠는 선택된 탭에 따라 전환
                Group {
                    switch selectedTab {
                    case .Home:
                        HomeView()
                    case .StreamingControl:
                        StreamingControlView()
                    }
                }

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
