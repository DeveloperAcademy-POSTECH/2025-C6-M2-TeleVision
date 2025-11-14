//
//  VoiceControlMenuButton.swift
//  Hippo
//
//  Voice-enabled Menu Toggle Button
//  Combines traditional tap-to-toggle with hands-free voice control
//

import SwiftUI

/// Voice-enabled Menu Toggle Button
///
/// Integrates menu toggle functionality with voice control, providing
/// dual interaction modes and real-time visual feedback.
///
/// **Interaction Modes:**
/// - Tap → Toggle menu + activate voice control (test mode)
/// - Hover → Voice control only (hands-free)
///
/// **Visual Feedback:**
/// - Button opacity changes based on menu and voice state
/// - Real-time STT transcription display
/// - Color-coded success/error messages
struct VoiceControlMenuButton: View {

    // MARK: - Constants

    private enum Constants {
        static let buttonSize: CGFloat = 160
        static let progressScale: CGFloat = 2.0
    }

    // MARK: - Environment

    @Environment(ImmersiveViewModel.self) private var immersiveViewModel

    // MARK: - State

    @State private var voiceControlVM: VoiceControlViewModel

    // MARK: - Properties

    /// Action to perform when button is tapped (menu toggle)
    let action: () -> Void

    // MARK: - Initialization

    /// Initialize with shared VoiceControlViewModel
    ///
    /// - Parameters:
    ///   - viewModel: VoiceControlViewModel instance (shared with overlay)
    ///   - action: Menu toggle action
    init(viewModel: VoiceControlViewModel, action: @escaping () -> Void) {
        _voiceControlVM = State(initialValue: viewModel)
        self.action = action
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            buttonImage

            // Real-time STT transcription
            if let partialText = voiceControlVM.uiState.partialTranscription, !partialText.isEmpty {
                transcriptionText(partialText)
            }

            // Command result feedback
            if shouldShowFeedback, let feedback = voiceControlVM.uiState.feedbackMessage {
                feedbackText(feedback)
            }

            // Status instruction message
            if let message = statusMessage {
                statusText(message)
            }
        }
        .onTapGesture(perform: handleTap)
    }

    // MARK: - Subviews

    /// Main button image with loading overlay
    @ViewBuilder
    private var buttonImage: some View {
        ZStack {
            Image("TopButton")
                .resizable()
                .frame(width: Constants.buttonSize, height: Constants.buttonSize)
                .opacity(buttonOpacity)

            // Loading indicator
            if voiceControlVM.uiState.isProcessing {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(Constants.progressScale)
                    .tint(.white)
            }
        }
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
            .background(Color.primary.opacity(0.15))
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
            .fontWeight(.semibold)
            .foregroundStyle(statusColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(statusBackground)
            .cornerRadius(8)
    }

    // MARK: - Computed Properties - State

    /// Current voice control state
    private var voiceState: VoiceControlState {
        voiceControlVM.uiState.state
    }

    /// Whether menu is currently open
    private var isMenuOpen: Bool {
        immersiveViewModel.isMenuActive
    }

    /// Button opacity (voice state > menu state priority)
    private var buttonOpacity: Double {
        switch voiceState {
        case .idle: isMenuOpen ? 1.0 : 0.25
        case .standby: 0.7
        case .listening: 1.0
        case .retry: 0.6
        }
    }

    // MARK: - Computed Properties - Messages

    /// Status instruction message based on voice state
    private var statusMessage: String? {
        switch voiceState {
        case .idle:
            nil
        case .standby:
            "'Hippo'라고 말하세요"
        case .listening:
            if voiceControlVM.uiState.isProcessing {
                "처리 중..."
            } else if voiceControlVM.uiState.feedbackType == .success {
                nil  // Hide when showing success feedback
            } else {
                "명령을 말씀해주세요"
            }
        case .retry:
            voiceControlVM.uiState.lastErrorMessage ?? "다시 시도해주세요"
        }
    }

    /// Whether to show feedback message
    private var shouldShowFeedback: Bool {
        voiceState == .listening && !voiceControlVM.uiState.isProcessing
    }

    /// Feedback text color based on feedback type
    private var feedbackColor: Color {
        switch voiceControlVM.uiState.feedbackType {
        case .success: .green
        case .error: .orange
        case .info: .blue
        }
    }

    /// Feedback background color based on feedback type
    private var feedbackBackground: some ShapeStyle {
        switch voiceControlVM.uiState.feedbackType {
        case .success: AnyShapeStyle(Color.green.opacity(0.15))
        case .error: AnyShapeStyle(Color.orange.opacity(0.15))
        case .info: AnyShapeStyle(Color.blue.opacity(0.15))
        }
    }

    /// Status text color based on voice state
    private var statusColor: Color {
        switch voiceState {
        case .idle: .secondary
        case .standby: .blue
        case .listening: .green
        case .retry: .orange
        }
    }

    /// Status background color based on voice state
    private var statusBackground: some ShapeStyle {
        switch voiceState {
        case .idle: AnyShapeStyle(Color.clear)
        case .standby: AnyShapeStyle(Color.blue.opacity(0.15))
        case .listening: AnyShapeStyle(Color.green.opacity(0.15))
        case .retry: AnyShapeStyle(Color.orange.opacity(0.15))
        }
    }

    // MARK: - Actions

    /// Handle button tap - toggle menu and activate voice control
    private func handleTap() {
        action()
        voiceControlVM.onWakeWordDetected()
    }

    /// Handle hover phase changes (disabled - using tap only)
    private func handleHover(_ phase: HoverPhase) {
        switch phase {
        case .active:
            voiceControlVM.onHoverBegan()
        case .ended:
            voiceControlVM.onHoverEnded()
        }
    }
}

// MARK: - Preview

#Preview {
    PreviewContainer()
}

// MARK: - Preview Helpers

private struct PreviewContainer: View {
    @State private var immersiveVM = ImmersiveViewModel()
    @State private var voiceControlVM = VoiceControlViewModel(
        commandExecutor: MockVoiceControlManager()
    )

    var body: some View {
        VoiceControlMenuButton(viewModel: voiceControlVM) {
            print("Menu toggled")
        }
        .environment(immersiveVM)
        .padding()
    }
}

/// Mock VoiceControlManager for previews and testing
internal struct MockVoiceControlManager: VoiceCommandExecutor {
    func execute(_ intent: VoiceCommandIntent) async throws {
        print("Mock execute: \(intent)")
    }
}
