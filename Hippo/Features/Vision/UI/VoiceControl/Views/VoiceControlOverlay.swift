//
//  VoiceControlOverlay.swift
//  Hippo
//
//  Voice Control Feedback Overlay
//
//  Responsibilities:
//  - Display feedback messages based on voice control state
//  - Show transcription results (for debugging/feedback)
//  - Provide visual feedback during different states
//
//  Usage Example:
//  ```swift
//  struct ImmersiveView: View {
//      @State private var voiceControlManager: VoiceControlManager
//      @State private var voiceControlVM: VoiceControlViewModel
//
//      init(manager: VoiceControlManager) {
//          _voiceControlManager = State(initialValue: manager)
//          _voiceControlVM = State(initialValue: VoiceControlViewModel(
//              commandExecutor: manager
//          ))
//      }
//
//      var body: some View {
//          ZStack {
//              // Main 3D content
//              RealityView { ... }
//
//              // Voice control button (triggers voice control)
//              VoiceControlMenuButton(manager: voiceControlManager) {
//                  // Toggle menu action
//              }
//
//              // Voice control feedback overlay (shows state messages)
//              VoiceControlOverlay(viewModel: voiceControlVM)
//          }
//      }
//  }
//  ```
//
//  Note: Button and Overlay should share the same VoiceControlViewModel instance
//        for synchronized state updates.
//

import SwiftUI

/// Voice Control Feedback Overlay
///
/// Displays state-based feedback messages to guide the user through
/// the voice control flow.
///
/// **Message Types:**
/// - Standby: Instructions for activating voice control
/// - Listening: Feedback that STT is active
/// - Retry: Error message with auto-retry notification
/// - Idle: No message (hidden)
public struct VoiceControlOverlay: View {

    // MARK: - Properties

    /// Voice control view model
    @Bindable var viewModel: VoiceControlViewModel

    // MARK: - Body

    public var body: some View {
        VStack {
            // Feedback message at top
            if let message = viewModel.uiState.feedbackMessage {
                feedbackCard(message: message)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()

            // Debug info at bottom (optional, can be removed in production)
            if let transcription = viewModel.uiState.lastTranscription {
                debugCard(transcription: transcription)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.uiState.feedbackMessage)
        .animation(.easeInOut(duration: 0.3), value: viewModel.uiState.lastTranscription)
    }

    // MARK: - Subviews

    /// Feedback message card
    @ViewBuilder
    private func feedbackCard(message: String) -> some View {
        HStack(spacing: 12) {
            // State icon
            stateIcon
                .font(.system(size: 20))
                .foregroundStyle(iconColor)

            // Message text
            Text(message)
                .font(.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

    /// Debug transcription card (for development/testing)
    @ViewBuilder
    private func debugCard(transcription: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("인식된 음성:")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(transcription)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    // MARK: - Computed Properties

    /// Icon based on current state
    @ViewBuilder
    private var stateIcon: some View {
        switch viewModel.uiState.state {
        case .idle:
            Image(systemName: "waveform.circle")

        case .standby:
            Image(systemName: "eye.fill")

        case .listening:
            Image(systemName: "waveform")

        case .retry:
            Image(systemName: "arrow.clockwise.circle.fill")
        }
    }

    /// Icon color based on current state
    private var iconColor: Color {
        switch viewModel.uiState.state {
        case .idle:
            return .secondary
        case .standby:
            return .blue
        case .listening:
            return .green
        case .retry:
            return .orange
        }
    }

    /// Card background based on current state
    private var cardBackground: some ShapeStyle {
        switch viewModel.uiState.state {
        case .idle:
            return AnyShapeStyle(Color.primary.opacity(0.05))
        case .standby:
            return AnyShapeStyle(Color.blue.opacity(0.1))
        case .listening:
            return AnyShapeStyle(Color.green.opacity(0.1))
        case .retry:
            return AnyShapeStyle(Color.orange.opacity(0.1))
        }
    }
}

// MARK: - Preview

#Preview {
    VoiceControlOverlay(viewModel: VoiceControlViewModel())
}
