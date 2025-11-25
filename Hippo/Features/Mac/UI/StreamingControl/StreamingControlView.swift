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
}

struct StreamingControlView: View {
    // MARK: - ViewModel

    @State private var viewModel = StreamingControlViewModel()

    private let videoLayer = AVSampleBufferDisplayLayer()

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

                PreviewSectionView(videoLayer: videoLayer)

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
//            .toolbar {
//                //우측 인스펙터 버튼
//                Button {
//                    viewModel.toggleInspector()
//                } label: { Label("Debug", systemImage: "sidebar.right") }
//            }
            .padding(32)
            .inspector(isPresented: $viewModel.isInspectorPresented) {
                StreamingInspectorView()
            }
            .task {
                // View가 나타날 때 장치 목록 로드 및 preview layer 연결
                viewModel.loadAvailableDevices()
                viewModel.previewLayer = videoLayer
            }
        }
    }
}

#Preview {
    RootView()
}
