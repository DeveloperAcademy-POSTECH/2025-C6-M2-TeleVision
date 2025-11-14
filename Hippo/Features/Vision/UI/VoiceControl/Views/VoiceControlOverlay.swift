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
            VStack(spacing: 8) {
                if let transcription = viewModel.uiState.lastTranscription {
                    debugCard(title: "인식된 음성", content: transcription)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if let intent = viewModel.uiState.lastParsedIntent {
                    debugCard(title: "파싱된 명령", content: intent)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.uiState.feedbackMessage)
        .animation(.easeInOut(duration: 0.3), value: viewModel.uiState.lastTranscription)
        .animation(.easeInOut(duration: 0.3), value: viewModel.uiState.lastParsedIntent)
    }

    // MARK: - Subviews

    /// Feedback message card
    @ViewBuilder
    private func feedbackCard(message: String) -> some View {
        HStack(spacing: 16) {
            // State icon with loading animation
            if isProcessing {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8)
            } else {
                stateIcon
                    .font(.system(size: 24))
                    .foregroundStyle(iconColor)
            }

            // Message text
            Text(message)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(cardBackground)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
        .padding(.horizontal, 32)
        .padding(.top, 32)
    }

    /// Check if currently processing (recognition or parsing)
    private var isProcessing: Bool {
        guard let message = viewModel.uiState.feedbackMessage else { return false }
        return message.contains("인식 중") || message.contains("분석 중")
    }

    /// Debug info card (for development/testing)
    @ViewBuilder
    private func debugCard(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title + ":")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text(content)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.secondary.opacity(0.15))
        .cornerRadius(16)
        .padding(.horizontal, 32)
        .padding(.bottom, 12)
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
