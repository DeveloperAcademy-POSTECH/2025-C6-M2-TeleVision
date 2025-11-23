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
    // 기본 모드: Demo (endoscope-demo.mp4 자동 재생)
    @StateObject private var streamUIState = StreamUIState(initialMode: .fileDemo)

    var body: some View {
        ZStack(alignment: .top) {
            // Main video view (uses shared uiState)
            // CRITICAL: Show view if connected OR in Demo mode
            EndoscopeStreamView(
                receiver: viewModel.webRTCReceiver,
                isVisible: viewModel.connectionStatus.isActive || streamUIState.activeMode == .fileDemo,
                uiState: streamUIState
            )
            .frame(minWidth: 900, minHeight: 600)

            // Connection status overlay (Demo 모드가 아니고 connected 상태가 아닐 때만 표시)
            if streamUIState.activeMode != .fileDemo && viewModel.connectionStatus != .connected {
                ConnectionOverlay(
                    status: viewModel.connectionStatus,
                    onSettingsPressed: {
                        showSettings = true
                    }
                )
                .padding(.top, 40)
            }

            // Top control bar overlay - visible when connected OR in demo mode
            if viewModel.connectionStatus == .connected || viewModel.activeMode == .fileDemo {
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
            // 기본 모드: Demo (endoscope-demo.mp4 자동 재생)
            // WebRTC 모드가 필요하면 상단 토글 버튼으로 전환 가능

            // Setup Demo cleanup callback
            streamUIState.onExitDemoMode = { [weak viewModel] in
                viewModel?.stopAll()
            }

            // CRITICAL: 파이프라인을 먼저 구성해서 VideoPlayer를 생성
            await viewModel.configure(for: .fileDemo)

            // VideoPlayer 초기화 완료 대기 (100ms)
            try? await Task.sleep(nanoseconds: 100_000_000)

            // 그 다음 UI 모드를 Demo로 전환 → Stereo3DView가 VideoPlayer를 물고 appear
            streamUIState.activeMode = .fileDemo
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
