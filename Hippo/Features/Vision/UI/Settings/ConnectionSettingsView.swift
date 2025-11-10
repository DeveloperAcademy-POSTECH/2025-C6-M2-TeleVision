//
//  ConnectionSettingsView.swift
//  Hippo
//
//  Manual server connection settings screen
//

import SwiftUI

struct ConnectionSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settings: ConnectionSettings

    var body: some View {
        NavigationStack {
            Form {
                // 연결 모드 선택
                Section {
                    Toggle("수동 연결 사용", isOn: $settings.useManualConnection)
                } header: {
                    Text("연결 모드")
                } footer: {
                    Text("자동 연결은 Bonjour를 사용하여 네트워크에서 서버를 찾습니다.\n수동 연결은 직접 서버 IP 주소를 입력합니다.")
                }

                // 수동 연결 설정
                if settings.useManualConnection {
                    Section {
                        HStack {
                            Text("서버 IP")
                                .frame(width: 80, alignment: .leading)
                            TextField("예: 192.168.0.10", text: $settings.serverIP)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.decimalPad)
                        }

                        HStack {
                            Text("포트")
                                .frame(width: 80, alignment: .leading)
                            TextField("8080", text: $settings.serverPort)
                                .keyboardType(.numberPad)
                        }
                    } header: {
                        Text("서버 정보")
                    } footer: {
                        if let url = settings.serverURL {
                            Text("연결 주소: \(url.absoluteString)")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("서버 IP 주소를 입력하세요")
                                .foregroundStyle(.red)
                        }
                    }

                    // IP 자동 감지
                    Section {
                        Button {
                            Task {
                                await settings.autoDetectServer()
                            }
                        } label: {
                            HStack {
                                if settings.isDetecting {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "wifi.circle.fill")
                                }
                                Text(settings.isDetecting ? "검색 중..." : "서버 자동 감지")
                            }
                        }
                        .disabled(settings.isDetecting)

                        if !settings.detectionStatus.isEmpty {
                            Text(settings.detectionStatus)
                                .font(.caption)
                                .foregroundStyle(settings.detectionStatus.contains("발견") ? .green : .secondary)
                        }
                    } header: {
                        Text("자동 감지")
                    } footer: {
                        Text("네트워크에서 서버를 자동으로 찾아 IP 주소를 입력합니다.")
                    }

                    // 도움말
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("💡 서버 IP 주소 확인 방법")
                                .font(.headline)

                            Text("1. Mac에서 터미널을 엽니다")
                            Text("2. 다음 명령어를 입력합니다:")
                            Text("   ifconfig | grep 'inet '")
                                .font(.system(.caption, design: .monospaced))
                                .padding(8)
                                .background(.quaternary)
                                .cornerRadius(4)
                            Text("3. Mac의 로컬 IP (예: 192.168.0.10)를 찾아 입력합니다")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    } header: {
                        Text("도움말")
                    }
                }

                // 디버깅 정보
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("저장된 IP:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(settings.serverIP.isEmpty ? "없음" : settings.serverIP)
                                .font(.caption.monospaced())
                                .foregroundStyle(.primary)
                        }

                        HStack {
                            Text("저장된 포트:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(settings.serverPort)
                                .font(.caption.monospaced())
                                .foregroundStyle(.primary)
                        }

                        HStack {
                            Text("수동 연결:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(settings.useManualConnection ? "켜짐" : "꺼짐")
                                .font(.caption)
                                .foregroundStyle(settings.useManualConnection ? .green : .secondary)
                        }
                    }
                } header: {
                    Text("현재 설정 상태")
                }

                // 초기화 버튼
                Section {
                    Button(role: .destructive) {
                        settings.reset()
                    } label: {
                        Text("설정 초기화")
                    }
                }
            }
            .navigationTitle("연결 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ConnectionSettingsView(settings: ConnectionSettings())
}
