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
    @State private var showSettings = false

    // UI state for coordinated mode transitions (shared with view and control bar)
    @StateObject private var streamUIState = StreamUIState(initialMode: .rawStream)

    var body: some View {
        ZStack(alignment: .top) {
            // Main video view (uses shared uiState)
            EndoscopeStreamView(
                receiver: viewModel.webRTCReceiver,
                isVisible: viewModel.connectionStatus.isActive,
                uiState: streamUIState
            )
            .frame(minWidth: 900, minHeight: 600)

            // Connection status overlay (connected 상태가 아닐 때만 표시)
            if viewModel.connectionStatus != .connected {
                ConnectionOverlay(
                    status: viewModel.connectionStatus,
                    onSettingsPressed: {
                        showSettings = true
                    }
                )
                .padding(.top, 40)
            }

            // Top control bar overlay - visible when connected
            if viewModel.connectionStatus == .connected {
                VStack {
                    HStack(spacing: 12) {
                        // Left: View mode toggle
                        ViewModeToggle(
                            uiState: streamUIState,
                            pipeline: viewModel.webRTCReceiver.renderPipeline
                        )

                        Spacer()

                        // Center-right: Connection status
                        ConnectionStatusBadge(receiver: viewModel.webRTCReceiver)

                        // Right: Settings button
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gear")
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .padding(6)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .hoverEffect()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                    .padding(.top, 40)  // Increased from 10 to 40
                    .padding(.horizontal, 50)  // Increased from 40 to 50

                    Spacer()
                }
                .zIndex(100)  // Move control bar above video in z-order
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
        .fullScreenCover(isPresented: $showSettings) {
            ConnectionSettingsView(settings: viewModel.settings)
                .onDisappear {
                    print("🔧 [WINDOW] ConnectionSettingsView dismissed")
                }
        }
        .onChange(of: showSettings) { oldValue, newValue in
            print("🔧 [WINDOW] showSettings changed: \(oldValue) → \(newValue)")
            // 설정 화면을 닫을 때 재연결
            if oldValue == true && newValue == false {
                print("🔧 [WINDOW] Settings closed - reconnecting...")
                Task {
                    await viewModel.disconnect()
                    print("🔧 [WINDOW] Disconnected, waiting 0.5s...")
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5초 대기
                    print("🔧 [WINDOW] Connecting...")
                    await viewModel.connect()
                    print("🔧 [WINDOW] Reconnection complete")
                }
            }
        }
    }
}
