//
//  PrimaryModeToggle.swift
//  Hippo
//
//  1단계 모드 토글: Live (WebRTC) vs Demo (파일 기반)
//  Live: 실시간 수술 장비 스트리밍
//  Demo: 녹화된 데모 영상 (Standard/3D)
//

import SwiftUI

/// 1단계 모드 토글: Live / Demo
struct PrimaryModeToggle: View {
    @ObservedObject var uiState: StreamUIState
    @ObservedObject var viewModel: EndoscopeStreamViewModel
    let pipeline: EndoscopeRenderPipeline

    var body: some View {
        HStack(spacing: 6) {
            // Live 버튼
            ModeButton(
                title: "Live",
                icon: "antenna.radiowaves.left.and.right",
                isSelected: uiState.isLiveMode,
                isDisabled: uiState.isSwitching
            ) {
                switchToLive()
            }

            // Demo 버튼
            ModeButton(
                title: "Demo",
                icon: "play.rectangle.fill",
                isSelected: uiState.isDemoMode,
                isDisabled: uiState.isSwitching
            ) {
                switchToDemo()
            }
        }
        .padding(4)
    }

    // MARK: - Actions

    private func switchToLive() {
        Task { @MainActor in
            guard uiState.isDemoMode else { return }

            print("[PrimaryModeToggle] Demo -> Live")
            viewModel.stopAll()

            let targetMode: EndoscopeViewMode = .rawStream
            await uiState.switchMode(to: targetMode, pipeline: pipeline)
            await viewModel.connect()

            print("[PrimaryModeToggle] Live mode ready")
        }
    }

    private func switchToDemo() {
        Task { @MainActor in
            guard uiState.isLiveMode else { return }

            print("[PrimaryModeToggle] Live -> Demo")
            viewModel.stopAll()

            // 현재 demoDisplayMode에 따라 적절한 Demo 모드로 전환
            if uiState.demoDisplayMode == .stereo3D {
                uiState.resetDemo3DSource()
                await viewModel.configureDemo3D(with: uiState.demo3DSource)
                uiState.activeMode = .fileDemo
            } else {
                uiState.activeMode = .fileDemo2D
            }

            print("[PrimaryModeToggle] Demo mode ready (\(uiState.demoDisplayMode.displayLabel))")
        }
    }
}

// MARK: - Mode Button Component

private struct ModeButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .white : .secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
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
