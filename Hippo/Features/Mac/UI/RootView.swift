//
//  ContentView.swift
//  HippoMac
//
//  Deprecated: Use PatientView instead
//

import SwiftUI

enum Tabs{
    case Home
    case StreamingControl
}

struct RootView: View {
    @State private var selectedTab: Tabs = .Home
    @State private var isTodaysSurgery: Bool = true
    
    var body: some View {
        NavigationStack {
            //탭바
            TabView(selection: $selectedTab) {
                Tab("Patients", systemImage: "", value: .Home) {
                    HomeView(isTodaysSurgery: $isTodaysSurgery)
                        .navigationTitle("Patient")
                }
                Tab("Camera", systemImage: "", value: .StreamingControl) {
                    StreamingControlView()
                        .navigationTitle("Camera")
                }
            }
            .onChange(of: selectedTab) {
                if selectedTab == .StreamingControl {
                    isTodaysSurgery = false
                }
                if selectedTab == .Home {
                    isTodaysSurgery = true
                }
            }
        }
        .toolbar {
            ToolbarItem {
                //툴바 우측 버튼
                if !isTodaysSurgery {
                    Button {
                        //TODO: 상황에 따라 버튼 기능 변경
                        switch selectedTab {
                        case .Home:
                            //CASE 1-2: HomeView에서 환자를 선택하지 않으면 버튼 없음
                            //CASE 1-2: HomeView에서 환자를 선택하면 수술 생성 버튼
                            print("홈뷰기능")
                        case .StreamingControl:
                            //CASE 2-1: StreamingControlView에서는 우측 디버깅 창 토글 버튼
                            print("스트리밍 뷰 기능")
                        }
                    } label: {
                        switch selectedTab {
                        case .Home:
                            //TODO: 환자 선택 전에는 비활성화/감춤 처리
                            Label("Create", systemImage: "plus")
                        case .StreamingControl:
                            Label("Debug", systemImage: "sidebar.right")
                        }
                    }
                }
                    
            }
        }
    }
}


#Preview {
    RootView()
}

