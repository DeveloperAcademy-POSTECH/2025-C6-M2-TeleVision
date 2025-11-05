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
            // 메인 컨텐츠는 선택된 탭에 따라 전환
            Group {
                switch selectedTab {
                case .Home:
                    HomeView()
                case .StreamingControl:
                    StreamingControlView()
                        .navigationTitle(Text("Hippo"))  //툴바 영역 허전해서 하나 넣어드림
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {  //.primaryAction: 툴바 아이템을 우측정렬
                    // 상단 탭 전환용 세그먼트 컨트롤
                    Picker("Section", selection: $selectedTab) {
                        Text("Patients").tag(Tabs.Home)
                        Text("Camera").tag(Tabs.StreamingControl)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .sheet(isPresented: $isOperationInputSheetPresented) {
                OperationInputView(isOperationInputSheetPresented: $isOperationInputSheetPresented)
            }
            
        }
    }
}

#Preview {
    RootView()
}
