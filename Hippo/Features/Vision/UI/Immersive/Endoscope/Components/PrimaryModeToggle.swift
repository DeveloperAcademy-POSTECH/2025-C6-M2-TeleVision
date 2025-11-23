//
//  PrimaryModeToggle.swift
//  Hippo
//
//  Primary mode toggle: WebRTC vs Demo
//  Handles top-level mode switching with proper resource cleanup
//

import SwiftUI

/// 1차 모드 토글: WebRTC 스트림 vs 3D Demo
/// - Demo → WebRTC: stopAll() → switchMode() → connect()
/// - WebRTC → Demo: stopAll() → configure(.fileDemo) → update UI
struct PrimaryModeToggle: View {
    @ObservedObject var uiState: StreamUIState
    @ObservedObject var viewModel: EndoscopeStreamViewModel
    let pipeline: EndoscopeRenderPipeline

    var body: some View {
        HStack(spacing: 8) {
            // WebRTC 스트림 버튼
            Button {
                Task { @MainActor in
                    // Demo → WebRTC로 갈 때만 동작
                    guard uiState.activeMode.isDemoMode else { return }

                    let targetMode: EndoscopeViewMode = .rawStream
                    print("🔄 [PrimaryModeToggle] Demo → WebRTC: Switching to \(targetMode.rawValue)")

                    // 1) Demo 소스 정리
                    viewModel.stopAll()

                    // 2) UI 상태 전환 (파이프라인 준비 포함)
                    await uiState.switchMode(to: targetMode, pipeline: pipeline)

                    // 3) WebRTC 연결 시작
                    print("   Initiating WebRTC connection...")
                    await viewModel.connect()

                    print("✅ [PrimaryModeToggle] WebRTC connection complete")
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 11))
                    Text("WebRTC 스트림")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(
                        uiState.activeMode.isWebRTCMode
                        ? Color.blue.opacity(0.2)
                        : Color.clear
                    )
                )
                .overlay(
                    Capsule().stroke(
                        uiState.activeMode.isWebRTCMode
                        ? Color.blue
                        : Color.clear,
                        lineWidth: 1
                    )
                )
            }
            .buttonStyle(.plain)
            .hoverEffect()
            .disabled(uiState.isSwitching)

            // 3D Demo 버튼
            Button {
                Task { @MainActor in
                    // WebRTC → Demo로 갈 때만 동작
                    guard uiState.activeMode.isWebRTCMode else { return }

                    print("🔄 [PrimaryModeToggle] WebRTC → Demo: Stopping WebRTC and configuring Demo")

                    // 1) WebRTC 완전 정리
                    viewModel.stopAll()

                    // 2) CRITICAL: VideoPlayer를 먼저 생성 (UI 전환 전에!)
                    //    이렇게 해야 Stereo3DView가 생성될 때 이미 VideoPlayer가 준비됨
                    print("   Configuring pipeline for fileDemo mode...")
                    await viewModel.configure(for: .fileDemo)

                    // 3) UI 상태를 Demo로 변경 (이제 VideoPlayer가 준비됨)
                    uiState.activeMode = .fileDemo

                    print("✅ [PrimaryModeToggle] Demo mode ready")
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 11))
                    Text("3D Demo")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(
                        uiState.activeMode.isDemoMode
                        ? Color.blue.opacity(0.2)
                        : Color.clear
                    )
                )
                .overlay(
                    Capsule().stroke(
                        uiState.activeMode.isDemoMode
                        ? Color.blue
                        : Color.clear,
                        lineWidth: 1
                    )
                )
            }
            .buttonStyle(.plain)
            .hoverEffect()
            .disabled(uiState.isSwitching)
        }
    }
}
