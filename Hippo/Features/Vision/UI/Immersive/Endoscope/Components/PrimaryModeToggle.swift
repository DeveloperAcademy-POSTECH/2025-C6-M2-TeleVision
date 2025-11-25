//
//  PrimaryModeToggle.swift
//  Hippo
//
//  Primary mode toggle: WebRTC vs Demo (2D/3D)
//  Handles top-level mode switching with proper resource cleanup
//

import SwiftUI

/// 1차 모드 토글: WebRTC 스트림 vs Demo (2D/3D)
/// - Demo → WebRTC: stopAll() → switchMode() → connect()
/// - WebRTC → Demo: stopAll() → configure(.fileDemo/.fileDemo2D) → update UI
/// - 2D Demo ↔ 3D Demo: UI 상태만 전환 (같은 Demo 모드 내 전환)
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
                    Text("WebRTC")
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

            // 2D Demo 버튼
            Button {
                Task { @MainActor in
                    // 이미 2D Demo면 무시
                    guard !uiState.activeMode.is2DDemo else { return }

                    print("🔄 [PrimaryModeToggle] Switching to 2D Demo")

                    if uiState.activeMode.isWebRTCMode {
                        // WebRTC → 2D Demo
                        viewModel.stopAll()
                    }

                    // 2D Demo는 파이프라인 설정 불필요 (AVPlayer 직접 사용)
                    // UI 상태만 변경하면 FileDemo2DView가 자체적으로 처리
                    uiState.activeMode = .fileDemo2D

                    print("✅ [PrimaryModeToggle] 2D Demo mode ready")
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 11))
                    Text("Demo")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(
                        uiState.activeMode.is2DDemo
                        ? Color.blue.opacity(0.2)
                        : Color.clear
                    )
                )
                .overlay(
                    Capsule().stroke(
                        uiState.activeMode.is2DDemo
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
                    // 이미 3D Demo면 무시
                    guard !uiState.activeMode.is3DDemo else { return }

                    print("🔄 [PrimaryModeToggle] Switching to 3D Demo")

                    if uiState.activeMode.isWebRTCMode {
                        // WebRTC → 3D Demo
                        viewModel.stopAll()
                    }

                    // CRITICAL: VideoPlayer를 먼저 생성 (UI 전환 전에!)
                    //    이렇게 해야 Stereo3DView가 생성될 때 이미 VideoPlayer가 준비됨
                    print("   Configuring pipeline for fileDemo mode...")
                    await viewModel.configure(for: .fileDemo)

                    // UI 상태를 3D Demo로 변경 (이제 VideoPlayer가 준비됨)
                    uiState.activeMode = .fileDemo

                    print("✅ [PrimaryModeToggle] 3D Demo mode ready")
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "cube.fill")
                        .font(.system(size: 11))
                    Text("3D Demo")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(
                        uiState.activeMode.is3DDemo
                        ? Color.blue.opacity(0.2)
                        : Color.clear
                    )
                )
                .overlay(
                    Capsule().stroke(
                        uiState.activeMode.is3DDemo
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
