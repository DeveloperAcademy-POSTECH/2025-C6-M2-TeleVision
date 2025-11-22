//
//  OperationMenuButton.swift
//  Hippo
//
//  Voice-enabled Menu Toggle Button
//  Combines traditional tap-to-toggle with hands-free voice control
//

import Lottie
import SwiftUI

/// Voice-enabled Menu Toggle Button
///
/// **Interaction Modes:**
/// - Tap → Toggle menu + activate voice control
/// - Hover → Activate voice control (hands-free mode)
struct OperationMenuButton: View {
    // MARK: - Constants

    private enum Constants {
        static let buttonSize: CGFloat = 80
        static let progressScale: CGFloat = 2.0
    }

    // MARK: - Environment

    @Environment(ImmersiveViewModel.self) private var immersiveViewModel

    // MARK: - Properties

    @Bindable var viewModel: VoiceControlViewModel
    let action: () -> Void

    // MARK: - Initialization

    init(viewModel: VoiceControlViewModel, action: @escaping () -> Void) {
        self.viewModel = viewModel
        self.action = action
    }

    // MARK: - Internal State

    @State private var visualState: VoiceVisualState = .idle

    private enum VoiceVisualState {
        case idle
        case starting
        case listening
        case ending
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            buttonImage

            //  Real-time STT transcription
            if let partialText = viewModel.uiState.partialTranscription, !partialText.isEmpty {
                transcriptionText(partialText)
            }

            // Command result feedback
            if viewModel.uiState.shouldShowFeedback, let feedback = viewModel.uiState.feedbackMessage {
                feedbackText(feedback)
            }

            // Status instruction message
            if let message = resolvedStatusMessage {
                statusText(message)
            }
        }
        .onTapGesture(perform: handleTap)
        .onContinuousHover { phase in
            handleHover(phase)
        }
        .onChange(of: viewModel.uiState.state) { oldValue, newValue in
            switch newValue {
            case .idle:
                if oldValue != .idle {
                    visualState = .ending
                }

            case .listening, .retry:
                visualState = .listening

            case .standby:
                visualState = .starting
            }
        }
        .help(immersiveViewModel.isMenuActive ? "집중 모드로 전환" : "")
    }

    // MARK: - Subviews

    /// Main button image with loading overlay
    @ViewBuilder
    private var buttonImage: some View {
        if visualState == .idle {
            ZStack {
                Image(buttonImageName)
                    .resizable()
                    .opacity(buttonOpacity)
                    .animation(.easeInOut(duration: 0.65), value: buttonOpacity)

                LottieView(animation: .named(isMenuOpen ? "hoverIn" : "hoverOut"))
                    .playing(.fromProgress(0, toProgress: 1, loopMode: .playOnce))

                if viewModel.uiState.isProcessing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(Constants.progressScale)
                        .tint(.white)
                }
            }
            .frame(width: Constants.buttonSize, height: Constants.buttonSize)
            .glassBackgroundEffect(in: .circle, displayMode: .always)
            .opacity(buttonOpacity)
        } else {
            ZStack {
                switch visualState {
                case .starting:
                    LottieView(animation: .named("VC_start"))
                        .playing(loopMode: .playOnce)
                        .animationDidFinish { _ in
                            visualState = .listening
                        }

                case .listening:
                    LottieView(animation: .named("VC_listening"))
                        .playing(loopMode: .loop)

                case .ending:
                    LottieView(animation: .named("VC_end"))
                        .playing(loopMode: .playOnce)
                        .animationDidFinish { _ in
                            visualState = .idle
                        }

                default: EmptyView()
                }
            }
            .frame(width: Constants.buttonSize + 20, height: Constants.buttonSize + 20)
        }
    }

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

    // MARK: - Computed Properties

    private var voiceState: VoiceControlState {
        viewModel.uiState.state
    }

    private var isMenuOpen: Bool {
        immersiveViewModel.isMenuActive
    }

    private var buttonOpacity: Double {
        switch voiceState {
        case .idle: isMenuOpen ? 1.0 : 0.25
        case .standby: 0.7
        case .listening: 1.0
        case .retry: 0.6
        }
    }

    private var buttonImageName: String {
        if isMenuOpen {
            "HeadAnchorOn"
        } else {
            "HeadAnchorOff"
        }
    }

    // MARK: - UI Mapping (Abstract → SwiftUI)

    /// Resolve abstract message key to actual text
    private var resolvedStatusMessage: String? {
        switch viewModel.uiState.statusMessageKey {
        case .none: return nil
        case .standbyGuide: return "'Hippo'라고 말하세요"
        case .listening: return "명령을 말씀해주세요"
        case .processing: return "처리 중..."
        case let .retry(errorMessage): return errorMessage ?? "다시 시도해주세요"
        }
    }

    /// Map color key to SwiftUI Color
    private var feedbackColor: Color {
        mapColorKey(viewModel.uiState.feedbackColorKey)
    }

    private var feedbackBackground: Color {
        mapColorKey(viewModel.uiState.feedbackColorKey).opacity(0.15)
    }

    private var statusColor: Color {
        switch voiceState {
        case .idle: return .secondary
        default: return mapColorKey(viewModel.uiState.statusColorKey)
        }
    }

    private var statusBackground: Color {
        switch voiceState {
        case .idle: return .clear
        default: return mapColorKey(viewModel.uiState.statusColorKey).opacity(0.15)
        }
    }

    private func mapColorKey(_ key: VoiceFeedbackColor) -> Color {
        switch key {
        case .success: return .green
        case .error: return .orange
        case .info: return .blue
        }
    }

    // MARK: - Actions

    private func handleTap() {
        action()
        viewModel.onWakeWordDetected()
    }

    private func handleHover(_ phase: HoverPhase) {
        switch phase {
        case .active:
            viewModel.onHoverBegan()
        case .ended:
            viewModel.onHoverEnded()
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        PreviewContainer()
    }

    fileprivate struct PreviewContainer: View {
        @State private var immersiveVM = ImmersiveViewModel()
        @State private var voiceControlVM = VoiceControlViewModel(
            commandExecutor: MockVoiceControlManager()
        )

        var body: some View {
            OperationMenuButton(viewModel: voiceControlVM) {
                print("Menu toggled")
            }
            .environment(immersiveVM)
            .padding()
        }
    }

    fileprivate struct MockVoiceControlManager: VoiceCommandExecutor {
        func execute(_ intent: VoiceCommandIntent) async throws {
            print("Mock execute: \(intent)")
        }
    }
#endif
