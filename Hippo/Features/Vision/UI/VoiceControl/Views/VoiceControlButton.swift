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
            // No click action - this is a hands-free, gaze-based interaction
        } label: {
            buttonLabel
        }
        .buttonStyle(.borderless)
        .onContinuousHover { phase in
            handleHover(phase: phase)
        }
    }

    // MARK: - Subviews

    /// Button label with icon and state indicator
    @ViewBuilder
    private var buttonLabel: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: iconName)
                .font(.system(size: 24))
                .foregroundStyle(iconColor)

            // State indicator (optional)
            if viewModel.uiState.state != .idle {
                stateIndicator
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(backgroundColor)
        .cornerRadius(12)
    }

    /// State indicator (visual feedback)
    @ViewBuilder
    private var stateIndicator: some View {
        Circle()
            .fill(stateIndicatorColor)
            .frame(width: 8, height: 8)
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

    // MARK: - Actions

    /// Handle hover phase changes
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
