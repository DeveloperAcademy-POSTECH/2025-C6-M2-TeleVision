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
    // 기본 상태: Demo + 3D + General (bird-3d.mov)
    @StateObject private var streamUIState = StreamUIState(initialMode: .fileDemo)

    var body: some View {
        ZStack {
            // 1) 메인 영상 뷰 (UI 없이 깔끔하게)
            EndoscopeStreamView(
                receiver: viewModel.webRTCReceiver,
                isVisible: viewModel.connectionStatus.isActive || streamUIState.isDemoMode,
                uiState: streamUIState
            )
            .frame(minWidth: 1200, minHeight: 800)

            // 2) 연결 상태 오버레이 (Live 모드 & 미연결일 때만)
            if streamUIState.isLiveMode && viewModel.connectionStatus != .connected {
                ConnectionOverlay(
                    status: viewModel.connectionStatus,
                    onSettingsPressed: { showSettings = true }
                )
            }
        }
        // ───────── 상단 ornament: 모드 전환 ─────────
        .ornament(
            visibility: viewModel.connectionStatus == .connected || streamUIState.isDemoMode
                ? .visible : .hidden,
            attachmentAnchor: .scene(.top),
            contentAlignment: .bottom
        ) {
            EndoscopeTopControlBar(
                uiState: streamUIState,
                viewModel: viewModel,
                showSettings: $showSettings
            )
            .glassBackgroundEffect()
            .cornerRadius(16)
            .padding(.bottom, 20)
        }
        // ───────── 하단 ornament: 3D Demo 소스 토글 (Demo + 3D일 때만) ─────────
        .ornament(
            visibility: streamUIState.isDemoMode && streamUIState.demoDisplayMode == .stereo3D
                ? .visible : .hidden,
            attachmentAnchor: .scene(.bottom),
            contentAlignment: .top
        ) {
            Demo3DSourceToggle(
                selected: streamUIState.demo3DSource,
                onChange: { newSource in
                    Task {
                        await viewModel.setDemo3DSource(newSource, uiState: streamUIState)
                    }
                },
                isSwitching: streamUIState.isSwitching
            )
            .glassBackgroundEffect()
            .cornerRadius(16)
            .padding(.top, 20)
        }
        // ───────── Lifecycle ─────────
        .task {
            streamUIState.onExitDemoMode = { [weak viewModel] in
                viewModel?.stopAll()
            }

            if streamUIState.activeMode == .fileDemo {
                print("[WINDOW] Initial 3D Demo setup with source: \(streamUIState.demo3DSource.rawValue)")
                await viewModel.configureDemo3D(with: streamUIState.demo3DSource)
            }
        }
        .onDisappear {
            Task {
                viewModel.stopAll()
            }
        }
        .fullScreenCover(isPresented: $showSettings) {
            ConnectionSettingsView(settings: viewModel.settings)
                .onDisappear {
                    print("[WINDOW] ConnectionSettingsView dismissed")
                }
        }
        .onChange(of: showSettings) { oldValue, newValue in
            print("[WINDOW] showSettings changed: \(oldValue) -> \(newValue)")
            if oldValue == true && newValue == false {
                print("[WINDOW] Settings closed - reconnecting...")
                Task {
                    await viewModel.disconnect()
                    print("[WINDOW] Disconnected, waiting 0.5s...")
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    print("[WINDOW] Connecting...")
                    await viewModel.connect()
                    print("[WINDOW] Reconnection complete")
                }
            }
        }
        .onChange(of: streamUIState.activeMode) { oldMode, newMode in
            print("[WINDOW] Mode changed: \(oldMode.rawValue) -> \(newMode.rawValue)")
        }
    }
}
