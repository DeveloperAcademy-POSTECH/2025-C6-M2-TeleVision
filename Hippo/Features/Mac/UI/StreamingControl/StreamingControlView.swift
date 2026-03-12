//
//  StreamingControlView.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/3/25.
//

import AVFoundation
import SwiftUI

enum VideoMode: String, CaseIterable {
    case fullSBS = "Full SBS"
    case halfSBS = "Half SBS"
    case mono = "Mono"
}

enum CameraInputMode: String, CaseIterable {
    case dual = "Dual"
    case single = "Single"
    case singleSBS = "Single SBS"
}

struct StreamingControlView: View {
    // MARK: - ViewModel

    /// Use shared singleton to persist across tab switches
    /// @Bindable allows $viewModel bindings to work with @Observable
    @Bindable private var viewModel = StreamingControlViewModel.shared

    var body: some View {
        ScrollView {
            HStack {
                Text("내시경 영상 관리")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.hippoGray700)

                Spacer()
            }
            .frame(height: 32)
            .padding(.top, 28)
            .padding(.horizontal, 32)
            .padding(.bottom)

            VStack(spacing: 20) {
                HStack(spacing: 20) {
                    ModeSectionView(
                        selectedMode: $viewModel.videoMode,
                        cameraInputMode: viewModel.cameraInputMode
                    )

                    ScalingSectionView(
                        selectedScaling: $viewModel.scalingMode,
                        isHalfBitrateEnabled: $viewModel.isHalfBitrateEnabled
                    )
                }

                CameraSectionView(
                    cameraInputMode: $viewModel.cameraInputMode,
                    selectedLeftDevice: $viewModel.selectedLeftDevice,
                    selectedRightDevice: $viewModel.selectedRightDevice,
                    selectedSingleDevice: $viewModel.selectedSingleDevice,
                    availableDevices: viewModel.availableDevices
                )

                PreviewSectionView(videoLayer: viewModel.previewLayer)

                StreamingButton(
                    isStreaming: viewModel.isStreaming,
                    isDisabled: viewModel.availableDevices.isEmpty
                ) {
                    Task {
                        do {
                            if viewModel.isStreaming {
                                viewModel.stopStreaming()
                            } else {
                                try await viewModel.startStreaming()
                            }
                        } catch {
                            print("Streaming error: \(error.localizedDescription)")
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(32)
            .inspector(isPresented: $viewModel.isInspectorPresented) {
                StreamingInspectorView()
            }
        }
    }
}

#Preview {
    RootView()
}
