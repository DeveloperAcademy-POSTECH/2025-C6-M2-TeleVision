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
    @State private var isTodaysSurgery: Bool = true
    @State private var isOperationInputSheetPresented: Bool = false

    var body: some View {
        NavigationStack {
            // 메인 컨텐츠는 선택된 탭에 따라 전환
            Group {
                switch selectedTab {
                case .Home:
                    HomeView(isTodaysSurgery: $isTodaysSurgery)
                case .StreamingControl:
                    StreamingControlView()
                        .navigationTitle(Text("")) //툴바 버튼 위치 유지를 위해 빈 문자열 타이틀 추가
                }
            }
            .onChange(of: selectedTab) {
                //StreamingControlView의 디버깅 패널 버튼의 존재가 isTodaysSurgery의 영향을 받지 않기 위해 추가함
                if selectedTab == .StreamingControl {
                    isTodaysSurgery = false
                } else if selectedTab == .Home {
                    isTodaysSurgery = true
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) { //.primaryAction: 툴바 아이템을 우측정렬
                    // 상단에 탭 전환용 세그먼트 컨트롤
                    Picker("Section", selection: $selectedTab) {
                        Text("Patients").tag(Tabs.Home)
                        Text("Camera").tag(Tabs.StreamingControl)
                    }
                    .pickerStyle(.segmented)

                    //툴바 우측 버튼
                    if !isTodaysSurgery {
                        Button {
                            //상황에 따라 버튼 기능이 달라짐
                            switch selectedTab {
                            case .Home:
                                //CASE 1: HomeView에서 환자를 선택하면 수술 생성 버튼
                                print("홈뷰기능")
                                isOperationInputSheetPresented = true
                                //TODO: 환자 생성 기능 구현
                            case .StreamingControl:
                                //CASE 2: StreamingControlView에서는 우측 디버깅 창 토글 버튼
                                print("스트리밍 뷰 기능")
                                //TODO: 디버깅 패널 토글 기능 구현
                            }
                        } label: {
                            switch selectedTab {
                            case .Home:
                                Label("Create", systemImage: "plus")
                            case .StreamingControl:
                                Label("Debug", systemImage: "sidebar.right")
                            }
                        }
                    }
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
