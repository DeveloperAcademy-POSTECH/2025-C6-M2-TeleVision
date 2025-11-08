//
//  EndoscopeStreamWindow.swift
//  Hippo
//
//  Endoscope video streaming window for Vision Pro
//  Manages WebRTC lifecycle and displays real-time stereo video from Mac
//

import SwiftUI
import RealityKit

struct EndoscopeStreamWindow: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var webRTCReceiver = WebRTCReceiver()

    var body: some View {
        EndoscopeStreamView(
            receiver: webRTCReceiver,
            isVisible: true
        )
        .frame(minWidth: 600, minHeight: 338)
        .task {
            // Start WebRTC connection when window appears
            do {
                try await webRTCReceiver.start()
            } catch {
                print("Failed to start WebRTC receiver: \(error)")
            }
        }
        .onDisappear {
            // Stop WebRTC connection when window closes
            Task {
                await webRTCReceiver.stop()
            }
        }
    }
}
