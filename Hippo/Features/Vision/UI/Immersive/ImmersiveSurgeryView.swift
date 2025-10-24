//
//  ImmersiveSurgeryView.swift
//  HippoVision
//
//  Created by 김현기 on 10/24/25.
//

import RealityKit
import SwiftUI

struct ImmersiveSurgeryView: View {
    @State private var runtime = ImmersiveSceneRuntime()
    @State private var viewModel = SurgeryViewModel()

    var body: some View {
        RealityView { content, attachments in
            runtime.setupScene(in: content, attachments: attachments)
        } attachments: {
            Attachment(id: AttachmentIDs.topToggleButton) {
                Image("TopButton")
                    .resizable()
                    .frame(width: 120, height: 120)
                    .opacity(viewModel.isMenuActive ? 1.0 : 0.25)
                    .onTapGesture {
                        viewModel.isMenuActive.toggle()
                    }
            }
            Attachment(id: AttachmentIDs.bottomMenuBar) {
                HStack {
                    Button {} label: {
                        ZStack {
                            // 메인 원
                            Circle()
                                .fill(.regularMaterial)
                                .frame(width: 80, height: 80)

                            // 민트색 링
                            Circle()
                                .stroke(.white, lineWidth: 3)
                                .frame(width: 40, height: 40)
                                .shadow(color: .cyan, radius: 20)
                        }
                        .glassBackgroundEffect(displayMode: .always)
                    }
                    .buttonStyle(.borderless)
                    .contentShape(.circle)
                    .frame(width: 80, height: 80)
                    .padding(24)

                    HStack {
                        VStack(alignment: .center) {
                            Toggle("", isOn: $viewModel.isEndoscopicActive)
                                .toggleStyle(.switch)
                                .labelsHidden()
                            Spacer().frame(height: 4)
                            Text("내시경")
                        }
                        .padding(30)

                        Spacer()

                        Button {} label: {
                            Text("수술 완료")
                                .padding()
                        }

                        Spacer()

                        Button {} label: {
                            HStack {
                                Text("녹화")
                                Spacer().frame(width: 16)
                                ZStack {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 28, height: 28) // 외부 원 크기 조정
                                        .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 3)

                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.red, .red.opacity(0.8)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .frame(width: 18, height: 18) // 내부 원 크기 조정
                                }
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, 12)
                        }
                        .padding(30)
                    }
                    .frame(width: 800)
                    .glassBackgroundEffect(displayMode: .always)

                    Button {} label: {
                        ZStack {
                            // 메인 원
                            Circle()
                                .fill(.regularMaterial)
                                .frame(width: 80, height: 80)

                            // 민트색 링
                            Circle()
                                .stroke(.white, lineWidth: 3)
                                .frame(width: 40, height: 40)
                                .shadow(color: .cyan, radius: 20)
                        }
                        .glassBackgroundEffect(displayMode: .always)
                    }
                    .buttonStyle(.borderless)
                    .contentShape(.circle)
                    .frame(width: 80, height: 80)
                    .padding(24)
                }
                .opacity(viewModel.isMenuActive ? 1.0 : 0.0)
            }
        }
        .onAppear { runtime.start() }
        .onDisappear { runtime.stop() }
    }
}

#Preview {
    ImmersiveSurgeryView()
}
