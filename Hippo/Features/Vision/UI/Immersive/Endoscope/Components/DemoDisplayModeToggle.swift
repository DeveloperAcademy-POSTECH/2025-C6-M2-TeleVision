//
//  DemoDisplayModeToggle.swift
//  Hippo
//
//  2단계 모드 토글: Demo 모드 내에서 Standard / 3D 선택
//  Demo 모드일 때만 표시됨
//

import SwiftUI

/// 2단계 모드 토글: Standard / 3D
/// Demo 모드 내에서 표시 방식 선택
struct DemoDisplayModeToggle: View {
    @ObservedObject var uiState: StreamUIState
    @ObservedObject var viewModel: EndoscopeStreamViewModel

    var body: some View {
        HStack(spacing: 6) {
            ForEach(DemoDisplayMode.allCases, id: \.self) { mode in
                DisplayModeButton(
                    mode: mode,
                    isSelected: uiState.demoDisplayMode == mode,
                    isDisabled: uiState.isSwitching
                ) {
                    switchDisplayMode(to: mode)
                }
            }
        }
        .padding(4)
    }

    // MARK: - Actions

    private func switchDisplayMode(to mode: DemoDisplayMode) {
        Task { @MainActor in
            guard uiState.demoDisplayMode != mode else { return }

            print("[DemoDisplayModeToggle] Switching to \(mode.displayLabel)")

            // 이전 리소스 정리
            viewModel.stopAll()

            // demoDisplayMode 업데이트
            uiState.demoDisplayMode = mode

            // 해당 모드로 전환
            switch mode {
            case .stereo3D:
                uiState.resetDemo3DSource()
                await viewModel.configureDemo3D(with: uiState.demo3DSource)
                uiState.activeMode = .fileDemo
            case .standard:
                uiState.activeMode = .fileDemo2D
            case .image:
                uiState.activeMode = .fileImage
            }

            print("[DemoDisplayModeToggle] \(mode.displayLabel) mode ready")
        }
    }
}

// MARK: - Display Mode Button Component

private struct DisplayModeButton: View {
    let mode: DemoDisplayMode
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: mode.icon)
                    .font(.system(size: 10))
                Text(mode.displayLabel)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(isSelected ? .white : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(
                    isSelected ? Color.blue.opacity(0.8) : Color.white.opacity(0.08)
                )
            )
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .disabled(isDisabled)
    }
}
