//
//  WebRTCSubModeToggle.swift
//  Hippo
//
//  WebRTC sub-mode toggle: Raw / Split / 3D
//  Only visible when in WebRTC mode (hidden in Demo mode)
//

import SwiftUI

/// WebRTC 서브 모드 토글: raw / split / 3D
/// WebRTC 모드일 때만 표시되며, raw → split → 3D → raw 순환
struct WebRTCSubModeToggle: View {
    @ObservedObject var uiState: StreamUIState
    let pipeline: EndoscopeRenderPipeline

    var body: some View {
        HStack(spacing: 6) {
            Button {
                Task { @MainActor in
                    // WebRTC 모드가 아니면 무시
                    guard uiState.activeMode.isWebRTCMode else { return }

                    let next = uiState.activeMode.nextWebRTCMode()
                    print("🔄 [WebRTCSubModeToggle] \(uiState.activeMode.rawValue) → \(next.rawValue)")

                    await uiState.switchMode(to: next, pipeline: pipeline)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: iconName(for: uiState.activeMode))
                        .font(.system(size: 10))
                    Text(title(for: uiState.activeMode))
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .hoverEffect()
            .disabled(uiState.isSwitching)
        }
        .opacity(uiState.activeMode.isWebRTCMode ? 1 : 0) // Demo에서는 감춤
        .animation(.easeInOut(duration: 0.2), value: uiState.activeMode.isWebRTCMode)
    }

    // MARK: - Helpers

    private func title(for mode: EndoscopeViewMode) -> String {
        switch mode {
        case .rawStream: return "원본 스트림"
        case .splitSBS:  return "좌우 분할"
        case .stereo3D:  return "3D 보기"
        case .fileDemo:  return "3D Demo"    // Should not be visible
        case .fileDemo2D: return "2D Demo"   // Should not be visible
        }
    }

    private func iconName(for mode: EndoscopeViewMode) -> String {
        switch mode {
        case .rawStream: return "rectangle.on.rectangle"
        case .splitSBS:  return "square.split.2x1"
        case .stereo3D:  return "view.3d"
        case .fileDemo:  return "cube"              // Should not be visible
        case .fileDemo2D: return "play.rectangle"   // Should not be visible
        }
    }
}
