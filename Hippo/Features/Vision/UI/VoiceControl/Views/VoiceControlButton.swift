//
//  VoiceControlButton.swift
//  Hippo
//
//  Voice Control Button Component
//
//  Responsibilities:
//  - Display voice control icon/button
//  - Detect hover state (gaze-based interaction)
//  - Trigger state transitions via ViewModel
//
//  Usage:
//  ```swift
//  VoiceControlButton(viewModel: voiceControlViewModel)
//  ```
//

import SwiftUI

/// Voice Control Button
///
/// A hands-free button that responds to user gaze (hover).
/// When the user looks at the button, it enters Standby mode.
/// When the user says "Hippo", voice control activates.
///
/// **Interaction Flow:**
/// - User looks at button → Standby (shows instructions)
/// - User says "Hippo" → Listening (STT starts)
/// - User looks away → Idle (deactivates)
public struct VoiceControlButton: View {

    // MARK: - Properties

    /// Voice control view model
    @Bindable var viewModel: VoiceControlViewModel

    // MARK: - Body

    public var body: some View {
        Button {
            // Test: Skip wake word detection, start STT directly
            // This is useful for testing voice control without implementing wake word detection
            print("🔘🔘🔘 [VoiceControlButton] BUTTON TAPPED!")
            handleTap()
        } label: {
            buttonLabel
        }
        .buttonStyle(.borderless)
        .hoverEffect()  // Vision Pro gaze interaction
        .onHover { isHovering in
            print("👁️👁️👁️ [VoiceControlButton] onHover: \(isHovering)")
        }
        .onContinuousHover { phase in
            print("👁️ [VoiceControlButton] onContinuousHover: \(phase)")
            handleHover(phase: phase)
        }
    }

    // MARK: - Subviews

    /// Button label with icon and state indicator
    @ViewBuilder
    private var buttonLabel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Loading indicator or icon
                if viewModel.uiState.isProcessing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.5)
                        .tint(iconColor)
                } else {
                    // Icon
                    Image(systemName: iconName)
                        .font(.system(size: 48))
                        .foregroundStyle(iconColor)
                }

                // State indicator (optional)
                if viewModel.uiState.state != .idle && !viewModel.uiState.isProcessing {
                    stateIndicator
                }
            }

            // Real-time transcription (shown during listening)
            if let partialText = viewModel.uiState.partialTranscription, !partialText.isEmpty {
                Text(partialText)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.1))
                    .cornerRadius(12)
                    .transition(.opacity.combined(with: .scale))
            }

            // Result/Feedback message (e.g., "✅ 메뉴가 닫힙니다")
            if let feedback = viewModel.uiState.feedbackMessage, viewModel.uiState.state == .listening && !viewModel.uiState.isProcessing {
                Text(feedback)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(feedbackMessageColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(feedbackMessageBackground)
                    .cornerRadius(12)
                    .transition(.opacity.combined(with: .scale))
            }

            // Status message
            if let message = statusMessage {
                Text(message)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .background(backgroundColor)
        .cornerRadius(24)
        .shadow(color: shadowColor, radius: 12, y: 6)
    }

    /// Shadow color based on state
    private var shadowColor: Color {
        switch viewModel.uiState.state {
        case .idle:
            return .clear
        case .standby:
            return .blue.opacity(0.3)
        case .listening:
            return .green.opacity(0.4)
        case .retry:
            return .orange.opacity(0.3)
        }
    }

    /// State indicator (visual feedback)
    @ViewBuilder
    private var stateIndicator: some View {
        Circle()
            .fill(stateIndicatorColor)
            .frame(width: 16, height: 16)
    }

    // MARK: - Computed Properties

    /// Icon name based on current state
    private var iconName: String {
        switch viewModel.uiState.state {
        case .idle:
            return "waveform.circle"
        case .standby:
            return "waveform.circle.fill"
        case .listening:
            return "waveform"
        case .retry:
            return "exclamationmark.circle"
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

    /// Background color based on current state
    private var backgroundColor: Color {
        switch viewModel.uiState.state {
        case .idle:
            return Color.clear
        case .standby, .listening, .retry:
            return Color.primary.opacity(0.1)
        }
    }

    /// State indicator color
    private var stateIndicatorColor: Color {
        switch viewModel.uiState.state {
        case .idle:
            return .clear
        case .standby:
            return .blue
        case .listening:
            return .green
        case .retry:
            return .orange
        }
    }

    /// Status message based on current state
    private var statusMessage: String? {
        switch viewModel.uiState.state {
        case .idle:
            return nil
        case .standby:
            return "'Hippo'라고 말하세요"
        case .listening:
            if viewModel.uiState.isProcessing {
                return "처리 중..."
            } else if viewModel.uiState.feedbackType == .success {
                return nil  // Don't show status when showing success feedback
            } else {
                return "명령을 말씀해주세요"
            }
        case .retry:
            return viewModel.uiState.lastErrorMessage ?? "다시 시도해주세요"
        }
    }

    /// Feedback message color based on type
    private var feedbackMessageColor: Color {
        switch viewModel.uiState.feedbackType {
        case .success:
            return .green
        case .error:
            return .orange
        case .info:
            return .blue
        }
    }

    /// Feedback message background based on type
    private var feedbackMessageBackground: some ShapeStyle {
        switch viewModel.uiState.feedbackType {
        case .success:
            return AnyShapeStyle(Color.green.opacity(0.15))
        case .error:
            return AnyShapeStyle(Color.orange.opacity(0.15))
        case .info:
            return AnyShapeStyle(Color.blue.opacity(0.15))
        }
    }

    // MARK: - Actions

    /// Handle button tap
    ///
    /// Simulates hover interaction: enters Standby mode and waits for wake word.
    ///
    /// Flow:
    /// 1. Tap button → Standby mode
    /// 2. Say "Hippo" → Wake word detected
    /// 3. Say command → Command executed
    ///
    /// Alternative: For direct testing without wake word, use `startListeningDirectly()`
    private func handleTap() {
        print("🔘 [VoiceControlButton] Tapped - Entering Standby (waiting for wake word)")

        // Simulate hover: Enter standby mode and start wake word listening
        if case .idle = viewModel.uiState.state {
            viewModel.onHoverBegan()
        }
    }

    /// Handle hover phase changes
    private func handleHover(phase: HoverPhase) {
        switch phase {
        case .active:
            print("👁️ [VoiceControlButton] Hover active detected")
            viewModel.onHoverBegan()

        case .ended:
            print("👁️ [VoiceControlButton] Hover ended detected")
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
