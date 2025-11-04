//
//  StreamingControlView.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/3/25.
//

import SwiftUI
import AVFoundation

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

    // Monoc
    @State private var selectedDeviceId: String = "FaceTime HD Camera"
    
    private let videoLayer = AVSampleBufferDisplayLayer()
    
    private let pickerCardViewMaxWidth: CGFloat = 600

    var body: some View {
        VStack {
            // 비디오인풋 선택
            VStack(alignment: .leading) {
                Text("VideoInputMode")
                Picker("", selection: $videoInputMode) {
                    Text("StereoVideo").tag(VideoInputMode.SideBySide)
                    Text("MonoVideo").tag(VideoInputMode.MonoVideo)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: pickerCardViewMaxWidth, alignment: .leading)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.gray.opacity(0.15))
            )

            // 카메라인풋선택: 3D로 출력하기 위한 영상 vs 2D로 출력하기 위한 영상
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
                .frame(maxWidth: pickerCardViewMaxWidth)

                
                switch videoInputMode {
                  
                case .SideBySide:  //3D로 출력하기 위한 영상(SBS)을 가져오려는 경우
                    switch cameraInputMode {
                       
                    case .DualInput: //SBS 영상을 두 개의 영상 처리기에서 받아오려는 경우
                        //TODO: 피커 내부 selectedDeviceId를 실제 데이터로 교체
                        //TODO: ForEach 내부 device는 실제 [AVCaptureDevice]로 교체
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
                        .frame(maxWidth: pickerCardViewMaxWidth)
                        
                    case .SingleInput: //SBS 영상을 한 개의 영상 처리기에서 받아오려는 경우
                        //TODO: 피커 내부 selectedDeviceId를 실제 데이터로 교체
                        //TODO: ForEach 내부 device는 실제 [AVCaptureDevice]로 교체
                        VStack(alignment: .leading) {
                            Picker("Camera", selection: $selectedDeviceId) {
                                ForEach(devices, id: \.self) { device in
                                    Text(device).tag(device)
                                }
                            }
                            .frame(maxWidth: pickerCardViewMaxWidth)
                        }
                    }
                    
                case .MonoVideo: //2D로 출력하기 위한 영상을 가져오려는 경우
                    VStack(alignment: .leading) {
                        //TODO: 피커 내부 selectedDeviceId를 실제 데이터로 교체
                        //TODO: ForEach 내부 device는 실제 [AVCaptureDevice]로 교체
                        Picker("Camera", selection: $selectedDeviceId) {
                            ForEach(devices, id: \.self) { device in
                                Text(device).tag(device)
                            }
                        }
                        .frame(maxWidth: pickerCardViewMaxWidth)
                    }
                }
                
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.gray.opacity(0.15))
            )

            Spacer()
            
            //영상 프리뷰
            DevicePreview(preview: videoLayer)
            //                .frame(width: 640, height: 360)
            //                .background(Color.black.opacity(0.1))
            
            //TODO: 스트리밍 시작 버튼
            Button {
                //TODO: RTP패킷 전송 기능 연결
            } label: {
                HStack {
                    Image(systemName: "play.fill") //TODO: 커스텀 아이콘으로 변경
                    Text("Start Streaming")
                }
            }
        }
        .padding()
    }
}

#Preview {
    StreamingControlView()
}
