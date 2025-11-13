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

    /// Initialize with VoiceControlManager for command execution
    ///
    /// - Parameters:
    ///   - manager: VoiceControlManager instance (acts as VoiceCommandExecutor)
    ///   - action: Action to perform when button is tapped (menu toggle)
    init(manager: VoiceControlManager, action: @escaping () -> Void) {
        _voiceControlVM = State(initialValue: VoiceControlViewModel(
            commandExecutor: manager
        ))
        self.action = action
    }

    // MARK: - Body

    var body: some View {
        Image("TopButton")
            .resizable()
            .frame(width: 120, height: 120)
            .opacity(buttonOpacity)
            .onTapGesture {
                handleTap()
            }
            .onContinuousHover { phase in
                handleHover(phase)
            }
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

    // MARK: - Actions

    /// Handle button tap
    ///
    /// Performs the traditional menu toggle action.
    /// Voice control state is not affected by taps.
    private func handleTap() {
        action()
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
            voiceControlVM.onHoverBegan()

        case .ended:
            // User looked away from button
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

    var body: some View {
        VoiceControlMenuButton(manager: MockVoiceControlManager()) {
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
