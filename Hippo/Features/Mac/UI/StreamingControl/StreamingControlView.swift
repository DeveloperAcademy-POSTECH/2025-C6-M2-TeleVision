//
//  StreamingControlView.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/3/25.
//

import SwiftUI

enum VideoInputMode {
    case SideBySide
    case MonoVideo
}

enum CameraInputMode {
    case DualInput
    case SingleInput
}

struct StreamingControlView: View {
    // MARK: - Dummy camera data
    private let devices: [String] = [
        "FaceTime HD Camera",
        "UVC Capture A",
        "UVC Capture B",
        "Virtual Cam 1",
        "Virtual Cam 2"
    ]

    // MARK: - State
    @State private var videoInputMode: VideoInputMode = .SideBySide
    @State private var cameraInputMode: CameraInputMode = .DualInput

    // Stereo
    @State private var selectedLeftDeviceId: String = "FaceTime HD Camera"
    @State private var selectedRightDeviceId: String = "UVC Capture A"

    // Monocular
    @State private var selectedMonoDeviceId: String = "FaceTime HD Camera"
    
    private let cardViewMaxWidth: CGFloat = 600

    var body: some View {
        VStack {
            // Mode
            VStack(alignment: .leading) {
                Text("VideoInputMode")
                Picker("", selection: $videoInputMode) {
                    Text("StereoVideo").tag(VideoInputMode.SideBySide)
                    Text("MonoVideo").tag(VideoInputMode.MonoVideo)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: cardViewMaxWidth, alignment: .leading)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.gray.opacity(0.15))
            )

            // Camera selection
            VStack {
                HStack {
                    Text("CameraInputMode")
                    Spacer()
                    if videoInputMode == .SideBySide {
                        Picker("", selection: $cameraInputMode) {
                            Text("DualInput").tag(CameraInputMode.DualInput)
                            Text("SingleInput").tag(CameraInputMode.SingleInput)
                        }
                        .pickerStyle(.segmented)

                    }
                }
                .frame(maxWidth: cardViewMaxWidth)

                switch videoInputMode {
                case .SideBySide:
                    // 두 개의 영상 처리기에서 받아오는 경우 두 개의 피커 생성 또는 단일 입력
                    switch cameraInputMode {
                    case .DualInput:
                        HStack {
                            Picker("Left Camera", selection: $selectedLeftDeviceId) {
                                ForEach(devices, id: \.self) { device in
                                    Text(device).tag(device)
                                }
                            }

                            Picker("Right Camera", selection: $selectedRightDeviceId) {
                                ForEach(devices, id: \.self) { device in
                                    Text(device).tag(device)
                                }
                            }
                        }
                        .frame(maxWidth: cardViewMaxWidth)

                    case .SingleInput:
                        VStack(alignment: .leading) {
                            Picker("Camera", selection: $selectedMonoDeviceId) {
                                ForEach(devices, id: \.self) { device in
                                    Text(device).tag(device)
                                }
                            }
                            .frame(maxWidth: cardViewMaxWidth)
                        }
                    }

                case .MonoVideo:
                    VStack(alignment: .leading) {
                        Picker("Camera", selection: $selectedMonoDeviceId) {
                            ForEach(devices, id: \.self) { device in
                                Text(device).tag(device)
                            }
                        }
                        .frame(maxWidth: cardViewMaxWidth)
                    }
                }
                
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.gray.opacity(0.15))
            )

            Spacer()
        }
        .padding()
    }
}

#Preview {
    StreamingControlView()
}
