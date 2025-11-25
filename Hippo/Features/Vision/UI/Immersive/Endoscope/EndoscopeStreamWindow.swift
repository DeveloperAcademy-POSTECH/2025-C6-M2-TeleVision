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

    // UI state for coordinated mode transitions (shared with view and control bar)
    // 기본 모드: 3D Demo (endoscope-demo.mp4 자동 재생)
    @StateObject private var streamUIState = StreamUIState(initialMode: .fileDemo)

    var body: some View {
        ZStack(alignment: .top) {
            // Main video view (uses shared uiState)
            // CRITICAL: Show view if connected OR in Demo mode (2D or 3D)
            EndoscopeStreamView(
                receiver: viewModel.webRTCReceiver,
                isVisible: viewModel.connectionStatus.isActive || streamUIState.activeMode.isDemoMode,
                uiState: streamUIState
            )
            .frame(minWidth: 900, minHeight: 600)

            // Connection status overlay (Demo 모드가 아니고 connected 상태가 아닐 때만 표시)
            if !streamUIState.activeMode.isDemoMode && viewModel.connectionStatus != .connected {
                ConnectionOverlay(
                    status: viewModel.connectionStatus,
                    onSettingsPressed: {
                        showSettings = true
                    }
                )
                .padding(.top, 40)
            }

            // Top control bar overlay - visible when connected OR in demo mode (2D or 3D)
            if viewModel.connectionStatus == .connected || streamUIState.activeMode.isDemoMode {
                VStack {
                    HStack(spacing: 16) {
                        // Left: Primary mode toggle (WebRTC vs Demo)
                        PrimaryModeToggle(
                            uiState: streamUIState,
                            viewModel: viewModel,
                            pipeline: viewModel.webRTCReceiver.renderPipeline
                        )

                        Spacer()

                        // Center: WebRTC sub-mode toggle (only visible in WebRTC mode)
                        WebRTCSubModeToggle(
                            uiState: streamUIState,
                            pipeline: viewModel.webRTCReceiver.renderPipeline
                        )

                        // Connection status (only in WebRTC mode)
                        if streamUIState.activeMode.isWebRTCMode {
                            ConnectionStatusBadge(receiver: viewModel.webRTCReceiver)
                        }

                        Spacer()

                        // Right: Settings button (always visible)
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
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                    .padding(.top, 40)
                    .padding(.horizontal, 50)

                    Spacer()
                }
                .zIndex(100)  // Move control bar above video in z-order
            }
        }
        .task {
            // Setup Demo cleanup callback
            streamUIState.onExitDemoMode = { [weak viewModel] in
                viewModel?.stopAll()
            }

            // 기본 모드: 3D Demo - 파이프라인 설정 필요
            if streamUIState.activeMode == .fileDemo {
                print("🎬 [WINDOW] Initial 3D Demo setup...")
                await viewModel.configure(for: .fileDemo)
            }
            // 2D Demo는 FileDemo2DView가 자체적으로 AVPlayer를 관리
        }
        .onDisappear {
            Task {
                // 모든 소스 정리
                viewModel.stopAll()
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
        .onChange(of: streamUIState.activeMode) { oldMode, newMode in
            print("🔄 [WINDOW] Mode changed: \(oldMode.rawValue) → \(newMode.rawValue)")
            // Note: WebRTC connection is handled by ViewModeToggle, not here
            // to avoid race conditions with switchMode()
        }
    }
}
