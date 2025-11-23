//
//  VoiceControlButton.swift
//  Hippo
//
//  Voice Control Button Component
//
//  Responsibilities:
//  - Display voice control icon/button with real-time feedback
//  - Detect hover state (gaze-based interaction)
//  - Show STT transcription and command results
//  - Trigger state transitions via ViewModel
//

import SwiftUI

/// Voice Control Button with real-time feedback
///
/// Hands-free button that responds to user gaze and provides visual feedback
/// for voice recognition, command parsing, and execution results.
///
/// **Interaction Flow:**
/// - User looks at button → Standby (shows wake word instruction)
/// - User says "Hippo" → Wake word detected feedback
/// - User speaks command → Real-time transcription displayed
/// - Command executes → Success message with color coding
/// - User looks away → Returns to Idle (clears all text)
public struct VoiceControlButton: View {
    // MARK: - Constants

    private enum Constants {
        static let buttonSize: CGFloat = 60
        static let iconSize: CGFloat = 28
        static let progressScale: CGFloat = 1.2
    }

    // MARK: - Properties

    /// Voice control view model
    @Bindable var viewModel: VoiceControlViewModel

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 12) {
            Button(action: handleTap) {
                buttonView
            }
            .buttonStyle(.plain)
            .hoverEffect()
            .onContinuousHover { phase in
                handleHover(phase: phase)
            }

            // Real-time STT transcription
            if let partialText = viewModel.uiState.partialTranscription, !partialText.isEmpty {
                transcriptionText(partialText)
            }

            // Command result feedback (success/error messages)
            if shouldShowFeedback, let feedback = viewModel.uiState.feedbackMessage {
                feedbackText(feedback)
            }

            // Status instruction message
            if let message = statusMessage {
                statusText(message)
            }
        }
    }

    // MARK: - Subviews

    /// Circular button view with glass effect
    @ViewBuilder
    private var buttonView: some View {
        ZStack {
            // Icon
            Image(systemName: "microphone")
                .font(.system(size: Constants.iconSize))
                .foregroundStyle(stateColor)

            // Loading indicator
            if viewModel.uiState.isProcessing {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(Constants.progressScale)
                    .tint(stateColor)
            }
        }
        .frame(width: Constants.buttonSize, height: Constants.buttonSize)
        .glassBackgroundEffect(in: .circle, displayMode: .always)
    }

    // MARK: - Text Components

    /// Real-time transcription text view
    @ViewBuilder
    private func transcriptionText(_ text: String) -> some View {
        Text(text)
            .font(.title3)
            .fontWeight(.medium)
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.1))
            .cornerRadius(12)
            .transition(.opacity.combined(with: .scale))
    }

    /// Feedback message text view (color-coded by type)
    @ViewBuilder
    private func feedbackText(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .fontWeight(.semibold)
            .foregroundStyle(feedbackColor)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(feedbackBackground)
            .cornerRadius(12)
            .transition(.opacity.combined(with: .scale))
    }

    /// Status instruction text view
    @ViewBuilder
    private func statusText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }

    // MARK: - Computed Properties - State

    /// Icon name based on voice control state
    /// Unified color for state (icon, indicator dot, shadow)
    private var stateColor: Color {
        switch viewModel.uiState.state {
        case .idle: .secondary
        case .standby: .blue
        case .listening: .green
        case .retry: .orange
        }
    }

    // MARK: - Computed Properties - Messages

    /// Status instruction message based on state
    private var statusMessage: String? {
        switch viewModel.uiState.state {
        case .idle:
            nil

        case .standby:
            "'Hippo'라고 말하세요"

        case .listening:
            if viewModel.uiState.isProcessing {
                "처리 중..."
            } else if viewModel.uiState.feedbackType == .success {
                nil // Hide when showing success feedback
            } else {
                "명령을 말씀해주세요"
            }

        case .retry:
            viewModel.uiState.lastErrorMessage ?? "다시 시도해주세요"
        }
    }

    /// Whether to show feedback message
    private var shouldShowFeedback: Bool {
        viewModel.uiState.state == .listening && !viewModel.uiState.isProcessing
    }

    /// Feedback text color based on feedback type
    private var feedbackColor: Color {
        switch viewModel.uiState.feedbackType {
        case .success: .green
        case .error: .orange
        case .info: .blue
        }
    }

    /// Feedback background color based on feedback type
    private var feedbackBackground: some ShapeStyle {
        switch viewModel.uiState.feedbackType {
        case .success: AnyShapeStyle(Color.green.opacity(0.15))
        case .error: AnyShapeStyle(Color.orange.opacity(0.15))
        case .info: AnyShapeStyle(Color.blue.opacity(0.15))
        }
    }

    // MARK: - Actions

    /// Handle button tap - activates voice control
    private func handleTap() {
        guard case .idle = viewModel.uiState.state else { return }
        viewModel.onHoverBegan()
    }

    /// Handle continuous hover phase changes
    private func handleHover(phase: HoverPhase) {
        switch phase {
        case .active:
            viewModel.onHoverBegan()
        case .ended:
            viewModel.onHoverEnded()
        }
    }
}

// MARK: - Preview

#Preview("Idle") {
    PreviewIdle()
}

#Preview("Standby") {
    PreviewStandby()
}

// MARK: - Preview Helpers

private struct PreviewIdle: View {
    @State private var vm = VoiceControlViewModel()

    var body: some View {
        VoiceControlButton(viewModel: vm)
            .padding()
    }
}

private struct PreviewStandby: View {
    @State private var vm: VoiceControlViewModel

    init() {
        let temp = VoiceControlViewModel()
        temp.onHoverBegan()
        _vm = State(initialValue: temp)
    }

    var body: some View {
        VoiceControlButton(viewModel: vm)
            .padding()
    }
}
