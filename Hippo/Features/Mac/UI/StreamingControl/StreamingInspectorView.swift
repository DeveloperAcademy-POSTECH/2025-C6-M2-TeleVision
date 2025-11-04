//
//  StreamingMonitorPanel.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/4/25.
//

import SwiftUI

struct StreamingInspectorView: View {
    //MARK: 더미 데이터
    enum NormalizationPolicy: String, CaseIterable, Identifiable {
        case cropScale = "Crop & Scale Down"
        case scaleDown = "Scale Down Only"
        case letterbox = "Letterbox Fit"
        case fitInside = "Fit Inside Frame"
        case stretchFill = "Stretch to Fill"
        case passthrough = "Passthrough (No Normalization)"

        var id: String { self.rawValue }
    }

    @State private var normalizationPolicy: NormalizationPolicy = .cropScale
    @State private var targetBitrate: Double = 6
    @State private var isControlsCollapsed: Bool = false
    @State private var isStatisticsCollapsed: Bool = false

    private let sliderMin = 5.0
    private let sliderMax = 20.0

    var body: some View {
        ScrollView {
            //Controls
            Section {
                if !isControlsCollapsed {
                    VStack {
                        //Normalization

                        HStack {
                            Text("Normalization Policy")
                            Spacer()
                        }
                        Picker("", selection: $normalizationPolicy) {  //TODO: 실제 방식으로 교체
                            ForEach(NormalizationPolicy.allCases) { policy in
                                Text(policy.rawValue).tag(policy)
                            }
                        }
                        .padding(.bottom)

                        //TargetBitrate
                        HStack {
                            Text("Target Bitrate: \(Int(targetBitrate)) Mbps")
                            Spacer()
                        }
                        //Slider
                        HStack {
                            Text("\(Int(sliderMin))")  //최소값 인디케이터
                            Slider(
                                value: $targetBitrate,
                                in: sliderMin...sliderMax
                            )
                            Text("\(Int(sliderMax))")  //최대값 인디케이터
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.gray.opacity(0.15))
                    )
                }
            } header: {
                HStack {
                    Text("Controls")
                    Spacer()
                    Button {  //TODO: 컴포넌트화: Statistics섹션에서도 동일한 기능 사용됨.
                        isControlsCollapsed.toggle()
                    } label: {
                        if !isControlsCollapsed {
                            Image(systemName: "chevron.down")
                        } else {
                            Image(systemName: "chevron.right")
                        }
                    }
                }

            }

            Spacer()

            //Statistics
            Section {
                if !isStatisticsCollapsed {
                    VStack {
                        //CaptureRate
                        Section {
                            HStack {
                                Text("Left")
                                Spacer()
                                Text("fps")
                                Spacer()
                                Text("Right")
                                Spacer()
                                Text("fps")
                            }
                            .padding(.bottom)
                        } header: {
                            HStack {
                                Text("CaptureRate")
                                Spacer()
                            }
                            Spacer()
                        }

                        //SynkRate
                        Section {
                            HStack {
                                Text("Pairs")
                                Spacer()
                                Text("fps")
                                Spacer()
                                Text("Drops")
                                Spacer()
                                Text("fps")
                            }
                            .padding(.bottom)
                        } header: {
                            HStack {
                                Text("SyncRate")
                                Spacer()
                            }
                            Spacer()
                        }

                        //Network
                        Section {
                            HStack {
                                Text("Bitrate")
                                Spacer()
                                Text("mbps")
                                Spacer()
                                Text("encode")
                                Spacer()
                                Text("fps")
                            }
                            .padding(.bottom)
                        } header: {
                            HStack {
                                Text("Network")
                                Spacer()
                            }
                            Spacer()
                        }

                        //Ratencies
                        Section {
                            VStack {
                                HStack {
                                    Text("Capture")
                                    Spacer()
                                    Text("ms")
                                    Spacer()
                                    Text("Compose")
                                    Spacer()
                                    Text("ms")
                                }
                                HStack {
                                    Text("Encode")
                                    Spacer()
                                    Text("ms")
                                    Spacer()
                                    Text("Right")
                                    Spacer()
                                    Text("E2E")
                                }
                            }

                            .padding(.bottom)
                        } header: {
                            HStack {
                                Text("Ratencies")
                                Spacer()
                            }
                            Spacer()
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.gray.opacity(0.15))
                    )
                }
            } header: {
                HStack {
                    Text("Statistics")
                    Spacer()
                    Button {  //TODO: 컴포넌트화: Statistics섹션에서도 동일한 기능 사용됨
                        isStatisticsCollapsed.toggle()
                    } label: {
                        if !isStatisticsCollapsed {
                            Image(systemName: "chevron.down")
                        } else {
                            Image(systemName: "chevron.right")
                        }
                    }
                }
            }
        }
        .padding()
    }
}

#Preview {
    StreamingInspectorView()
}
