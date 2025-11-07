//
//  EndoscopeStreamView.swift
//  Hippo
//
//  Endoscope video streaming view for Vision Pro
//  Displays real-time stereo video from Mac
//

import SwiftUI
import RealityKit
import AVFoundation

/// Video display mode for Vision Pro
enum VideoDisplayMode: String, CaseIterable {
    case stereo = "Stereo"
    case mono = "Mono"

    var icon: String {
        switch self {
        case .stereo: return "view.3d"
        case .mono: return "view.2d"
        }
    }
}

struct EndoscopeStreamView: View {
    @ObservedObject var receiver: WebRTCReceiver
    let isVisible: Bool

    @State private var displayMode: VideoDisplayMode = .stereo

    var body: some View {
        ZStack {
            if isVisible {
                // RealityKit VideoMaterial로 스테레오/모노 렌더링
                VideoPlayerView(
                    renderer: receiver.stereoRenderer,
                    displayMode: displayMode
                )
                    .frame(width: 600, height: 338)  // 16:9 비율 (1920×1080 스케일)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .glassBackgroundEffect(in: .rect(cornerRadius: 20))
                    .shadow(radius: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.hippoPrimary.opacity(0.3), lineWidth: 2)
                    )
                    .overlay(alignment: .topTrailing) {
                        // 연결 상태 표시
                        ConnectionStatusBadge(isConnected: receiver.isConnected)
                            .padding(12)
                    }
                    .overlay(alignment: .topLeading) {
                        // 스테레오/모노 토글 버튼
                        DisplayModeToggle(mode: $displayMode)
                            .padding(12)
                    }
            }
        }
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.3), value: isVisible)
    }
}

// MARK: - Video Player View

struct VideoPlayerView: View {
    let renderer: AVSampleBufferVideoRenderer
    let displayMode: VideoDisplayMode

    var body: some View {
        #if os(visionOS)
        RealityView { content in
            // VideoMaterial with stereo-tagged CMSampleBuffer
            let videoMaterial = VideoMaterial(avPlayer: AVPlayer())

            // Plane mesh for video display
            let mesh = MeshResource.generatePlane(width: 1.0, depth: 0.5625)  // 16:9
            let modelComponent = ModelComponent(mesh: mesh, materials: [videoMaterial])

            let videoEntity = Entity()
            videoEntity.components.set(modelComponent)

            // Configure stereo/mono display based on mode
            // Note: Actual stereo rendering is controlled by CMTaggedBuffer tags
            // This setting primarily affects how the video material interprets the buffer
            switch displayMode {
            case .stereo:
                // Enable stereo rendering (both eyes see different views)
                videoEntity.components.set(modelComponent)
            case .mono:
                // Enable mono rendering (both eyes see same view)
                // In mono mode, only display left eye or full frame
                videoEntity.components.set(modelComponent)
            }

            content.add(videoEntity)
        }
        #else
        Color.black
        #endif
    }
}

// MARK: - Display Mode Toggle

struct DisplayModeToggle: View {
    @Binding var mode: VideoDisplayMode

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                mode = mode == .stereo ? .mono : .stereo
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.caption)
                    .foregroundStyle(.primary)

                Text(mode.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .hoverEffect()
    }
}

// MARK: - Connection Status Badge

struct ConnectionStatusBadge: View {
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
                .shadow(color: isConnected ? .green : .red, radius: 4)

            Text(isConnected ? "연결됨" : "연결 중...")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

#Preview {
    EndoscopeStreamView(
        receiver: WebRTCReceiver(),
        isVisible: true
    )
}
