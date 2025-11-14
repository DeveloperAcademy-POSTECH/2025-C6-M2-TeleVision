//
//  VoiceControlMenuButton.swift
//  Hippo
//
//  Voice-enabled Menu Toggle Button
//  Combines traditional tap-to-toggle with hands-free voice control
//
//  Interaction Modes:
//  1. Tap → Toggle menu (traditional)
//  2. Hover → Voice control activation (hands-free)
//
//  ViewModel Ownership:
//  - ViewModel은 버튼 내부에서 소유하지만,
//  - overlay 등 다른 UI에서 동일 인스턴스를 공유할 가능성을 고려해
//  - 추후 주입 방식 개선 여지를 남겨둠.
//

import SwiftUI

/// Voice-enabled Menu Toggle Button
///
/// This button integrates menu toggle functionality with voice control:
///
/// **Traditional Interaction (Tap):**
/// - User taps button → Menu toggles open/closed
///
/// **Voice Interaction (Hover):**
/// - User gazes at button → Enters Standby mode
/// - User says "Hippo" → Listening mode activates
/// - User looks away → Returns to Idle mode
///
/// **Visual Feedback:**
/// - Opacity changes based on menu state and voice control state
struct VoiceControlMenuButton: View {

    // MARK: - Environment

    @Environment(ImmersiveViewModel.self) private var immersiveViewModel

    // MARK: - State

    @State private var voiceControlVM: VoiceControlViewModel

    // MARK: - Properties

    /// Action to perform when button is tapped
    let action: () -> Void

    // MARK: - Initialization

    /// Initialize with VoiceControlViewModel
    ///
    /// - Parameters:
    ///   - viewModel: VoiceControlViewModel instance (shared with overlay)
    ///   - action: Action to perform when button is tapped (menu toggle)
    init(viewModel: VoiceControlViewModel, action: @escaping () -> Void) {
        _voiceControlVM = State(initialValue: viewModel)
        self.action = action
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Main button image
                Image("TopButton")
                    .resizable()
                    .frame(width: 160, height: 160)
                    .opacity(buttonOpacity)

                // Loading indicator overlay
                if voiceControlVM.uiState.isProcessing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(2.0)
                        .tint(.white)
                }
            }

            // Real-time transcription (shown during listening)
            if let partialText = voiceControlVM.uiState.partialTranscription, !partialText.isEmpty {
                Text(partialText)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.15))
                    .cornerRadius(12)
                    .transition(.opacity.combined(with: .scale))
            }

            // Result/Feedback message (e.g., "✅ 메뉴가 닫힙니다")
            if let feedback = voiceControlVM.uiState.feedbackMessage, voiceState == .listening && !voiceControlVM.uiState.isProcessing {
                Text(feedback)
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

            // Status message
            if let message = statusMessage {
                Text(message)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(statusMessageColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(statusMessageBackground)
                    .cornerRadius(8)
            }
        }
//        .hoverEffect()  // Vision Pro gaze interaction
        .onTapGesture {
            print("🔘🔘🔘 [VoiceControlMenuButton] IMAGE TAPPED!")
            handleTap()
        }
//        .onHover { isHovering in
//            print("👁️👁️👁️ [VoiceControlMenuButton] onHover: \(isHovering)")
//        }
//        .onContinuousHover { phase in
//            print("👁️ [VoiceControlMenuButton] onContinuousHover: \(phase)")
//            handleHover(phase)
//        }
    }

    // MARK: - Computed Properties

    /// Whether the menu is currently open
    private var isMenuOpen: Bool {
        immersiveViewModel.isMenuActive
    }

    /// Current voice control state
    private var voiceState: VoiceControlState {
        voiceControlVM.uiState.state
    }

    /// Button opacity based on menu state and voice control state
    ///
    /// Priority: Voice control state > Menu state
    /// - Voice control active (standby/listening/retry): Override menu opacity
    /// - Voice control idle: Follow menu state (open=1.0, closed=0.25)
    private var buttonOpacity: Double {
        switch voiceState {
        case .idle:
            // No voice control active - follow menu state
            return isMenuOpen ? 1.0 : 0.25

        case .standby:
            // Waiting for wake word - slightly dimmed
            return 0.7

        case .listening:
            // Actively listening - full brightness for visual feedback
            return 1.0

        case .retry:
            // Error state - dimmed to indicate problem
            return 0.6
        }
    }

    /// Status message based on voice control state
    private var statusMessage: String? {
        switch voiceState {
        case .idle:
            return nil
        case .standby:
            return "'Hippo'라고 말하세요"
        case .listening:
            if voiceControlVM.uiState.isProcessing {
                return "처리 중..."
            } else if voiceControlVM.uiState.feedbackType == .success {
                return nil  // Don't show status when showing success feedback
            } else {
                return "명령을 말씀해주세요"
            }
        case .retry:
            return voiceControlVM.uiState.lastErrorMessage ?? "다시 시도해주세요"
        }
    }

    /// Feedback message color based on type
    private var feedbackColor: Color {
        switch voiceControlVM.uiState.feedbackType {
        case .success:
            return .green
        case .error:
            return .orange
        case .info:
            return .blue
        }
    }

    /// Feedback message background based on type
    private var feedbackBackground: some ShapeStyle {
        switch voiceControlVM.uiState.feedbackType {
        case .success:
            return AnyShapeStyle(Color.green.opacity(0.15))
        case .error:
            return AnyShapeStyle(Color.orange.opacity(0.15))
        case .info:
            return AnyShapeStyle(Color.blue.opacity(0.15))
        }
    }

    /// Status message color based on voice control state
    private var statusMessageColor: Color {
        switch voiceState {
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

    /// Status message background based on voice control state
    private var statusMessageBackground: some ShapeStyle {
        switch voiceState {
        case .idle:
            return AnyShapeStyle(Color.clear)
        case .standby:
            return AnyShapeStyle(Color.blue.opacity(0.15))
        case .listening:
            return AnyShapeStyle(Color.green.opacity(0.15))
        case .retry:
            return AnyShapeStyle(Color.orange.opacity(0.15))
        }
    }

    // MARK: - Actions

    /// Handle button tap
    ///
    /// Performs:
    /// 1. Menu toggle action (original functionality)
    /// 2. Start voice recognition (for testing)
    private func handleTap() {
        action()

        // Test: Also start STT directly on tap
        print("🔘 [VoiceControlMenuButton] Starting STT on tap (test mode)")
        voiceControlVM.onWakeWordDetected()
    }

    /// Handle hover phase changes
    ///
    /// Activates voice control when user gazes at the button.
    ///
    /// - Parameter phase: Current hover phase (active/ended)
    private func handleHover(_ phase: HoverPhase) {
        switch phase {
        case .active:
            // User started looking at button
            print("👁️ [VoiceControlMenuButton] Hover active detected")
            voiceControlVM.onHoverBegan()

        case .ended:
            // User looked away from button
            print("👁️ [VoiceControlMenuButton] Hover ended detected")
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
