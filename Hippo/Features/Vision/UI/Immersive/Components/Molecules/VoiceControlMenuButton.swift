//
//  VoiceControlMenuButton.swift
//  Hippo
//
//  Voice-enabled Menu Toggle Button
//  Combines traditional tap-to-toggle with hands-free voice control
//

import SwiftUI
import Lottie


/// Voice-enabled Menu Toggle Button
///
/// **Interaction Modes:**
/// - Tap → Toggle menu + activate voice control
/// - Hover → Activate voice control (hands-free mode)
struct VoiceControlMenuButton: View {
    
    // MARK: - Constants
    
    private enum Constants {
        static let buttonSize: CGFloat = 70
        static let progressScale: CGFloat = 2.0
    }
    
    // MARK: - Environment
    
    @Environment(ImmersiveViewModel.self) private var immersiveViewModel
    
    // MARK: - Properties
    
    @Bindable var viewModel: VoiceControlViewModel
    let action: () -> Void
    @State private var show = false
    @State private var hasShownTooltip = false
    
    
    // MARK: - Initialization
    
    init(viewModel: VoiceControlViewModel, action: @escaping () -> Void) {
        self.viewModel = viewModel
        self.action = action
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack {
            ZStack {
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
                //        .hoverEffect()
                .onContinuousHover { phase in
                    handleHover(phase)
                }
            }
            
            TooltipView(tooltipText: "버튼 클릭 시\n집중 모드로 전환됩니다.", isVisible: $show)
                .opacity(show ? 1 : 0)
            
        }
        .task {
            guard !hasShownTooltip else { return }
            hasShownTooltip = true
            
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run {
                withAnimation(.easeInOut) {
                    show = true
                }
            }
            
            try? await Task.sleep(for: .seconds(6))
            await MainActor.run {
                withAnimation(.easeInOut) {
                    show = false
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    /// Main button image with loading overlay
    @ViewBuilder
    private var buttonImage: some View {
        VStack {
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
            .buttonStyle(.borderless)
            .opacity(buttonOpacity)
            .frame(width: Constants.buttonSize, height: Constants.buttonSize)
            .glassBackgroundEffect(in: .circle, displayMode: .always)
            
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
        case .retry(let errorMessage): return errorMessage ?? "다시 시도해주세요"
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

#Preview {
    PreviewContainer()
}

#if DEBUG
fileprivate struct PreviewContainer: View {
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

fileprivate struct MockVoiceControlManager: VoiceCommandExecutor {
    func execute(_ intent: VoiceCommandIntent) async throws {
        print("Mock execute: \(intent)")
    }
}
#endif
