//
//  EndoscopeTopControlBar.swift
//  Hippo
//
//  상단 ornament용 컨트롤 바
//  1단계: Live / Demo
//  2단계: Demo일 때 Standard / 3D
//

import SwiftUI

struct EndoscopeTopControlBar: View {
    @ObservedObject var uiState: StreamUIState
    @ObservedObject var viewModel: EndoscopeStreamViewModel
    @Binding var showSettings: Bool

    var body: some View {
        HStack(spacing: 16) {
            // 1단계: Live / Demo
            PrimaryModeToggle(
                uiState: uiState,
                viewModel: viewModel,
                pipeline: viewModel.webRTCReceiver.renderPipeline
            )

            // 2단계: Demo일 때만 Standard / 3D 토글
            if uiState.isDemoMode {
                Divider()
                    .frame(height: 20)
                    .opacity(0.3)

                DemoDisplayModeToggle(
                    uiState: uiState,
                    viewModel: viewModel
                )
            }

            // Live 모드일 때만: WebRTC 서브모드 + 연결 상태 + 설정
            if uiState.isLiveMode {
                Divider()
                    .frame(height: 20)
                    .opacity(0.3)

                WebRTCSubModeToggle(
                    uiState: uiState,
                    pipeline: viewModel.webRTCReceiver.renderPipeline
                )

                ConnectionStatusBadge(receiver: viewModel.webRTCReceiver)

                Divider()
                    .frame(height: 20)
                    .opacity(0.3)

                SettingsButton(showSettings: $showSettings)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Settings Button Component

private struct SettingsButton: View {
    @Binding var showSettings: Bool

    var body: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .padding(10)
                .background(
                    Circle().fill(Color.white.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
    }
}
