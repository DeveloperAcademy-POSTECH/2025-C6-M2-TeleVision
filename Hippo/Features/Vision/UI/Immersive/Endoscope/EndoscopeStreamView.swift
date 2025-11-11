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

/// Rendering path selection for video display
enum VideoRenderPath: String, CaseIterable {
    case metal = "Metal"
    case videoPlayer = "VideoPlayer"

    var icon: String {
        switch self {
        case .metal: return "cube.fill"
        case .videoPlayer: return "play.rectangle.fill"
        }
    }
}

struct EndoscopeStreamView: View {
    @ObservedObject var receiver: WebRTCReceiver
    let isVisible: Bool

    @State private var displayMode: VideoDisplayMode = .stereo
    @State private var renderPath: VideoRenderPath = .videoPlayer

    var body: some View {
        ZStack {
            if isVisible {
                // Select rendering path
                Group {
                    switch renderPath {
                    case .metal:
                        // Path B: Use StereoVideoRenderer (Metal-based)
                        StereoVideoView(
                            renderer: receiver.stereoMetalRenderer,
                            displayMode: displayMode
                        )
                    case .videoPlayer:
                        // Path A: Use VideoPlayerComponent (AVSampleBufferVideoRenderer)
                        VideoPlayerStereoView(
                            receiver: receiver,
                            displayMode: displayMode
                        )
                    }
                }
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
                    VStack(alignment: .leading, spacing: 8) {
                        // 스테레오/모노 토글 버튼
                        DisplayModeToggle(mode: $displayMode)
                        // 렌더링 경로 토글 버튼
                        RenderPathToggle(path: $renderPath, receiver: receiver)
                    }
                    .padding(12)
                }
            }
        }
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.3), value: isVisible)
        .onAppear {
            // Initialize receiver's render path to match UI state
            receiver.setRenderPath(renderPath == .metal ? .metal : .videoPlayer)
        }
    }
}

// MARK: - Path A: VideoPlayer-based Stereo View

struct VideoPlayerStereoView: View {
    @ObservedObject var receiver: WebRTCReceiver
    let displayMode: VideoDisplayMode

    @State private var videoEntity: Entity?

    var body: some View {
        #if os(visionOS)
        RealityView { content in
            // Create VideoPlayerComponent using the stereoRenderer
            let videoPlayerComponent = VideoPlayerComponent(videoRenderer: receiver.stereoRenderer)
            let entity = Entity()
            entity.components.set(videoPlayerComponent)
            entity.scale = SIMD3<Float>(repeating: 1)
            content.add(entity)

            // Store reference for potential updates
            videoEntity = entity
        } update: { content in
            // Update logic if needed when receiver state changes
            // Currently, the stereoRenderer is continuously updated via enqueue
        }
        .onAppear {
            print("✅ VideoPlayerStereoView appeared, stereoRenderer status: \(receiver.stereoRenderer.status.rawValue)")
        }
        #else
        Color.black
            .overlay(
                Text("Stereo video requires visionOS")
                    .foregroundColor(.white)
            )
        #endif
    }
}

// MARK: - Path B: Metal-based Stereo Video View (using StereoVideoRenderer)

struct StereoVideoView: View {
    @ObservedObject var renderer: StereoVideoRenderer
    let displayMode: VideoDisplayMode

    var body: some View {
        #if os(visionOS)
        RealityView { content in
            // Setup the stereo video scene with left/right planes
            renderer.setupScene(in: content)
        }
        #else
        Color.black
            .overlay(
                Text("Stereo video requires visionOS")
                    .foregroundColor(.white)
            )
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

// MARK: - Render Path Toggle

struct RenderPathToggle: View {
    @Binding var path: VideoRenderPath
    @ObservedObject var receiver: WebRTCReceiver

    var body: some View {
        Button {
            // Toggle path
            let newPath: VideoRenderPath = path == .metal ? .videoPlayer : .metal

            withAnimation(.easeInOut(duration: 0.2)) {
                path = newPath
            }

            // Update receiver's render path (this will cleanup old renderer and prepare new one)
            receiver.setRenderPath(newPath == .metal ? .metal : .videoPlayer)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: path.icon)
                    .font(.caption)
                    .foregroundStyle(.primary)

                Text(path.rawValue)
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
