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
    @State private var displayMode: VideoDisplayMode = .stereo
    @State private var renderPath: VideoRenderPath = .videoPlayer

    var body: some View {
        ZStack(alignment: .top) {
            // Main video view
            EndoscopeStreamView(
                receiver: viewModel.webRTCReceiver,
                isVisible: viewModel.connectionStatus.isActive,
                displayMode: $displayMode,
                renderPath: $renderPath
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

            // Top control bar overlay - visible when connected
            if viewModel.connectionStatus == .connected {
                VStack {
                    HStack(spacing: 12) {
                        // Left: Control buttons
                        DisplayModeToggle(mode: $displayMode)
                        RenderPathToggle(path: $renderPath, receiver: viewModel.webRTCReceiver)

                        Spacer()

                        // Center-right: Connection status
                        ConnectionStatusBadge(receiver: viewModel.webRTCReceiver)

                        // Right: Settings button
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gear")
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .padding(6)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .hoverEffect()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    .padding(.top, 10)  // Moved closer to top
                    .padding(.horizontal, 40)

                    Spacer()
                }
                .zIndex(100)  // Move control bar above video in z-order
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
                .onDisappear {
                    print("🔧 [WINDOW] ConnectionSettingsView dismissed")
                }
        }
        .onChange(of: showSettings) { oldValue, newValue in
            print("🔧 [WINDOW] showSettings changed: \(oldValue) → \(newValue)")
            // 설정 화면을 닫을 때 재연결
            if oldValue == true && newValue == false {
                print("🔧 [WINDOW] Settings closed - reconnecting...")
                Task {
                    await viewModel.disconnect()
                    print("🔧 [WINDOW] Disconnected, waiting 0.5s...")
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5초 대기
                    print("🔧 [WINDOW] Connecting...")
                    await viewModel.connect()
                    print("🔧 [WINDOW] Reconnection complete")
                }
            }
        }
    }
}
