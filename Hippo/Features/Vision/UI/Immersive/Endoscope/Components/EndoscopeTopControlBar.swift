//
//  EndoscopeTopControlBar.swift
//  Hippo
//
//  상단 ornament용 컨트롤 바
//  모드 전환 + WebRTC 상태 + 설정 버튼
//

import SwiftUI

struct EndoscopeTopControlBar: View {
    @ObservedObject var uiState: StreamUIState
    @ObservedObject var viewModel: EndoscopeStreamViewModel
    @Binding var showSettings: Bool

    var body: some View {
        HStack(spacing: 20) {
            // Left: Primary mode toggle (WebRTC / Demo / 3D Demo)
            PrimaryModeToggle(
                uiState: uiState,
                viewModel: viewModel,
                pipeline: viewModel.webRTCReceiver.renderPipeline
            )

            // Center: WebRTC sub-mode toggle (only in WebRTC mode)
            if uiState.activeMode.isWebRTCMode {
                Divider()
                    .frame(height: 20)
                    .opacity(0.3)

                WebRTCSubModeToggle(
                    uiState: uiState,
                    pipeline: viewModel.webRTCReceiver.renderPipeline
                )

                ConnectionStatusBadge(receiver: viewModel.webRTCReceiver)
            }

            Divider()
                .frame(height: 20)
                .opacity(0.3)

            // Right: Settings button
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
            .hoverEffect(.highlight)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
