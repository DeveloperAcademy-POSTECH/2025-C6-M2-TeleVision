//
//  EndoscopeStreamWindow.swift
//  Hippo
//
//  Endoscope video streaming window for Vision Pro
//  Displays real-time stereo video from Mac using Bonjour auto-discovery
//

import SwiftUI
import RealityKit

struct EndoscopeStreamWindow: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = EndoscopeStreamViewModel()
    @State private var showSettings = false

    var body: some View {
        ZStack(alignment: .top) {
            // Main video view
            EndoscopeStreamView(
                receiver: viewModel.webRTCReceiver,
                isVisible: viewModel.connectionStatus.isActive
            )
            .frame(minWidth: 600, minHeight: 338)

            // Connection status overlay (connected 상태가 아닐 때만 표시)
            if viewModel.connectionStatus != .connected {
                ConnectionOverlay(
                    status: viewModel.connectionStatus,
                    onSettingsPressed: {
                        showSettings = true
                    }
                )
                .padding(.top, 40)
            }

            // Connected 상태에서도 설정 버튼 표시
            if viewModel.connectionStatus == .connected {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gear")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(.regularMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 60)
                        .padding(.trailing, 30)
                    }
                    Spacer()
                }
            }
        }
        .task {
            await viewModel.connect()
        }
        .onDisappear {
            Task {
                await viewModel.disconnect()
            }
        }
        .fullScreenCover(isPresented: $showSettings) {
            ConnectionSettingsView(settings: viewModel.settings)
        }
        .onChange(of: showSettings) { oldValue, newValue in
            // 설정 화면을 닫을 때 재연결
            if oldValue == true && newValue == false {
                Task {
                    await viewModel.disconnect()
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5초 대기
                    await viewModel.connect()
                }
            }
        }
    }
}
