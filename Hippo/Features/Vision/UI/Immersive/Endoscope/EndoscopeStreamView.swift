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
    @Binding var viewMode: EndoscopeViewMode

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
            Group {
                // Route to appropriate view based on pipeline mode
                switch viewMode {
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
                        pipeline: receiver.renderPipeline
                    )
                }
            }
            .id(viewMode.rawValue)  // Force recreation on mode change
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
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.3), value: isVisible)
            .onAppear {
                // Sync receiver to current view mode
                receiver.setViewMode(viewMode)
            }
            .onChange(of: viewMode) { oldMode, newMode in
                // Update receiver when view mode changes
                receiver.setViewMode(newMode)
            }
        }
    }
}

// MARK: - View Mode Toggle

struct ViewModeToggle: View {
    @Binding var mode: EndoscopeViewMode

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                // Cycle through modes: Raw → SplitSBS → Stereo3D → Raw
                switch mode {
                case .rawStream:
                    mode = .splitSBS
                case .splitSBS:
                    mode = .stereo3D
                case .stereo3D:
                    mode = .rawStream
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: mode.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)

                Text(mode.description)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .hoverEffect()
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
    @State private var viewMode: EndoscopeViewMode = .stereo3D
    @StateObject private var mockPipeline: EndoscopeRenderPipeline
    @StateObject private var mockReceiver: WebRTCReceiver

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
            viewMode: $viewMode
        )
    }
}

#Preview {
    EndoscopeStreamView_PreviewWrapper()
}
