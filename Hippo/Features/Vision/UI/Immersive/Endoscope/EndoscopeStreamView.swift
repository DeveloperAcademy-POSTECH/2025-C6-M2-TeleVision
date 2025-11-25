//
//  EndoscopeStreamView.swift
//  Hippo
//
//  Endoscope video streaming view for Vision Pro
//  Displays real-time stereo video from Mac
//  Refactored to use 3-stage pipeline (Raw / Split / Stereo3D)
//

import SwiftUI
import RealityKit
import AVFoundation

// MARK: - Main Stream View

struct EndoscopeStreamView: View {
    @ObservedObject var receiver: WebRTCReceiver
    let isVisible: Bool

    // UI state for coordinated mode transitions (injected from parent)
    @ObservedObject var uiState: StreamUIState

    // Calculate dynamic view size based on frame resolution
    private var viewSize: CGSize {
        let frameSize = receiver.currentFrameSize

        // If no frame size yet, use default 16:9
        guard frameSize.width > 0 && frameSize.height > 0 else {
            return CGSize(width: 900, height: 600)
        }

        // Maximum display dimensions (fits well in Vision Pro window)
        let maxWidth: CGFloat = 1200
        let maxHeight: CGFloat = 900

        let aspectRatio = frameSize.width / frameSize.height

        // Calculate size with aspect fit
        var width = maxWidth
        var height = width / aspectRatio

        if height > maxHeight {
            height = maxHeight
            width = height * aspectRatio
        }

        return CGSize(width: width, height: height)
    }

    var body: some View {
        if isVisible {
            ZStack {
                // Main content - route based on activeMode (not viewMode)
                Group {
                    switch uiState.activeMode {
                    case .fileDemo2D:
                        // 2D Demo: AVPlayer + VideoMaterial (no pipeline)
                        FileDemo2DView()

                    case .rawStream:
                        RawStreamView(
                            receiver: receiver,
                            pipeline: receiver.renderPipeline
                        )

                    case .splitSBS:
                        SplitSBSView(
                            receiver: receiver,
                            pipeline: receiver.renderPipeline
                        )

                    case .stereo3D:
                        Stereo3DView(
                            receiver: receiver,
                            pipeline: receiver.renderPipeline,
                            mode: .stereo3D
                        )

                    case .fileDemo:
                        // 3D Demo 전용 뷰 (WebRTC와 분리)
                        // demo3DSource가 바뀌면 View 재생성하여 새 VideoPlayer 연결
                        FileDemo3DView(pipeline: receiver.renderPipeline)
                            .id(uiState.demo3DSource.rawValue)
                    }
                }
                .id(uiState.activeMode.rawValue)  // Force recreation on mode change
                .frame(width: viewSize.width, height: viewSize.height)
                .onChange(of: viewSize) { oldValue, newValue in
                    if oldValue != newValue {
                        print("📐 View size changed: \(Int(oldValue.width))×\(Int(oldValue.height)) → \(Int(newValue.width))×\(Int(newValue.height))")
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .glassBackgroundEffect(in: .rect(cornerRadius: 20))
                .shadow(radius: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.hippoPrimary.opacity(0.3), lineWidth: 2)
                )

                // Switching overlay
                if uiState.isSwitching {
                    Color.black.opacity(0.4)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                    .tint(.white)

                                Text("모드 전환 중...")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                            .padding(24)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .transition(.opacity)
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.3), value: isVisible)
            .animation(.easeInOut(duration: 0.2), value: uiState.isSwitching)
            .onAppear {
                // CRITICAL: Demo 모드는 외부에서 configure 호출하므로 여기서는 건너뜀
                // Demo 모드는 EndoscopeStreamWindow에서 직접 관리됨
                guard !uiState.activeMode.isDemoMode else {
                    print("⏭️ [EndoscopeStreamView] Skipping configure for Demo mode (handled externally)")
                    return
                }

                // Sync pipeline to initial mode (WebRTC modes only)
                print("🔄 [EndoscopeStreamView] onAppear - configuring pipeline for: \(uiState.activeMode.rawValue)")
                receiver.renderPipeline.configure(for: uiState.activeMode)
            }
        }
    }
}

// MARK: - View Mode Toggle

struct ViewModeToggle: View {
    @ObservedObject var uiState: StreamUIState
    let pipeline: EndoscopeRenderPipeline

    var body: some View {
        Button {
            // Async mode transition: Pipeline → View
            // NOTE: This toggle only cycles through WebRTC modes
            // Demo mode is separate and not part of this cycle
            Task { @MainActor in
                // Determine next WebRTC mode (Raw → Split → Stereo3D → Raw)
                let nextMode: EndoscopeViewMode
                switch uiState.activeMode {
                case .rawStream:
                    nextMode = .splitSBS
                case .splitSBS:
                    nextMode = .stereo3D
                case .stereo3D:
                    nextMode = .rawStream
                case .fileDemo, .fileDemo2D:
                    // Demo modes are not part of WebRTC cycle
                    // This should never happen (button is hidden in Demo mode)
                    print("⚠️ [ViewModeToggle] Toggle pressed in Demo mode - ignoring")
                    return
                }

                // Switch mode with proper pipeline preparation
                await uiState.switchMode(to: nextMode, pipeline: pipeline)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: uiState.activeMode.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)

                Text(uiState.activeMode.description)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .hoverEffect()
        .disabled(uiState.isSwitching)  // Disable during transition
    }
}

// MARK: - Connection Status Badge

struct ConnectionStatusBadge: View {
    @ObservedObject var receiver: WebRTCReceiver

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(receiver.isConnected ? Color.green : Color.red)
                .frame(width: 6, height: 6)
                .shadow(color: receiver.isConnected ? .green : .red, radius: 3)

            Text(receiver.isConnected ? "연결됨" : "연결 중...")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: - Preview

@MainActor
private struct EndoscopeStreamView_PreviewWrapper: View {
    @StateObject private var mockPipeline: EndoscopeRenderPipeline
    @StateObject private var mockReceiver: WebRTCReceiver
    @StateObject private var mockUIState = StreamUIState(initialMode: .stereo3D)

    init() {
        // @MainActor 컨텍스트에서 파이프라인 생성
        let pipeline = EndoscopeRenderPipeline()
        _mockPipeline = StateObject(wrappedValue: pipeline)

        // DI 패턴으로 파이프라인을 주입한 Receiver 생성
        _mockReceiver = StateObject(
            wrappedValue: WebRTCReceiver(renderPipeline: pipeline)
        )
    }

    var body: some View {
        EndoscopeStreamView(
            receiver: mockReceiver,
            isVisible: true,
            uiState: mockUIState
        )
    }
}

#Preview {
    EndoscopeStreamView_PreviewWrapper()
}
