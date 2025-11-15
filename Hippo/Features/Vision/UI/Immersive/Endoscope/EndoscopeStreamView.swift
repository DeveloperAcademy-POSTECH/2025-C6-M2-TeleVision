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
    @Binding var displayMode: VideoDisplayMode
    @Binding var renderPath: VideoRenderPath

    // Calculate dynamic view size based on frame resolution
    private var viewSize: CGSize {
        let frameSize = receiver.currentFrameSize

        // If no frame size yet, use default 16:9
        guard frameSize.width > 0 && frameSize.height > 0 else {
            return CGSize(width: 600, height: 338)
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
        // Video content only - controls moved to EndoscopeStreamWindow overlay
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
            .id("\(renderPath.rawValue)-\(displayMode.rawValue)")
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
                // Initialize receiver's render path to match UI state
                receiver.setRenderPath(renderPath == .metal ? .metal : .videoPlayer)
            }
        }
    }
}

// MARK: - Path A: VideoPlayer-based Stereo View

struct VideoPlayerStereoView: View {
    @ObservedObject var receiver: WebRTCReceiver
    let displayMode: VideoDisplayMode

    @State private var videoEntity: Entity?
    @State private var isRendererReady = false

    // Fixed plane dimensions for video display
    // VideoPlayerComponent will scale the video to fit the plane
    private var planeDimensions: (width: Float, height: Float) {
        // Optimized size for performance and visibility
        // 16:9 aspect ratio - reduced from 4.0m for better performance
        return (width: 2.4, height: 1.35)  // ~2.4m wide, maintains 16:9 ratio
    }

    var body: some View {
        #if os(visionOS)
        RealityView { content in
            print("🎬 VideoPlayerStereoView: Creating RealityView")
            print("   Renderer status: \(receiver.stereoRenderer.status.rawValue)")
            print("   Ready for data: \(receiver.stereoRenderer.isReadyForMoreMediaData)")

            // Create VideoPlayerComponent with StereoVideoPlayer's renderer
            // Note: receiver.stereoRenderer is a computed property that returns videoPlayer.videoRenderer
            let videoPlayerComponent = VideoPlayerComponent(videoRenderer: receiver.stereoRenderer)

            // Create entity with VideoPlayerComponent ONLY (no mesh, no materials needed)
            // VideoPlayerComponent automatically creates and manages its own stereo rendering plane
            let entity = Entity()
            entity.components.set(videoPlayerComponent)

            // MATCH Metal position: Same as StereoVideoRenderer for consistency
            // In ImmersiveSpace, position at origin like Metal planes
            entity.position = SIMD3<Float>(0, 0, 0)

            // Set scale for comfortable viewing
            let dimensions = planeDimensions
            entity.scale = SIMD3<Float>(repeating: 1.0)  // 1:1 scale with plane dimensions

            content.add(entity)

            // Store reference for potential updates
            videoEntity = entity

            print("✅ VideoPlayerComponent created with scale: \(entity.scale.x), plane: \(dimensions.width)m × \(dimensions.height)m)")

            // Monitor for pink screen issues - check renderer status periodically
            Task {
                for _ in 0..<10 {
                    try? await Task.sleep(for: .seconds(1))
                    let status = receiver.stereoRenderer.status
                    let readyForData = receiver.stereoRenderer.isReadyForMoreMediaData

                    if status == .failed {
                        print("❌ [PINK SCREEN DEBUG] Renderer status: FAILED")
                    } else if !readyForData {
                        print("⚠️ [PINK SCREEN DEBUG] Renderer not ready for data")
                    }
                }
            }
        }
        .frame(depth: 0)
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
        .frame(depth: 0)
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
            HStack(spacing: 4) {
                Image(systemName: mode.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)

                Text(mode.rawValue)
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
            HStack(spacing: 4) {
                Image(systemName: path.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)

                Text(path.rawValue)
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

#Preview {
    struct PreviewWrapper: View {
        @State private var displayMode: VideoDisplayMode = .stereo
        @State private var renderPath: VideoRenderPath = .videoPlayer

        var body: some View {
            EndoscopeStreamView(
                receiver: WebRTCReceiver(),
                isVisible: true,
                displayMode: $displayMode,
                renderPath: $renderPath
            )
        }
    }

    return PreviewWrapper()
}
