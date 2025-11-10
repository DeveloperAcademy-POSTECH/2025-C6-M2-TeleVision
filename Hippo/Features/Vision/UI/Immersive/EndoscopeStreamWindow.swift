//
//  EndoscopeStreamWindow.swift
//  Hippo
//
//  Endoscope video streaming window for Vision Pro
//  Displays real-time stereo video from Mac using Bonjour auto-discovery
//

import SwiftUI
import RealityKit

struct EndoscopeStreamWindow: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = EndoscopeStreamViewModel()

    var body: some View {
        ZStack {
            // Main video view
            EndoscopeStreamView(
                receiver: viewModel.webRTCReceiver,
                isVisible: viewModel.connectionStatus.isActive
            )
            .frame(minWidth: 600, minHeight: 338)

            // Connection status overlay
            if !viewModel.connectionStatus.isActive {
                ConnectionOverlay(status: viewModel.connectionStatus)
            }
        }
        .task {
            await viewModel.connect()
        }
        .onDisappear {
            Task {
                await viewModel.disconnect()
            }
        }
    }
}
