//
//  ConnectionOverlay.swift
//  Hippo
//
//  Connection status overlay component
//  Displays discovering, connecting, and error states
//

import SwiftUI

struct ConnectionOverlay: View {
    let status: EndoscopeStreamViewModel.ConnectionStatus
    let onSettingsPressed: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            switch status {
            case .idle:
                VStack(spacing: 12) {
                    Image(systemName: "network")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("서버 연결 대기 중")
                        .font(.headline)

                    Button {
                        onSettingsPressed()
                    } label: {
                        Label("연결 설정", systemImage: "gear")
                    }
                    .buttonStyle(.bordered)
                }

            case .discovering:
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.hippoPrimary)
                Text("서버 검색 중...")
                    .font(.headline)
                Text("Mac에서 서버가 실행 중인지 확인하세요")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    onSettingsPressed()
                } label: {
                    Label("수동 연결", systemImage: "gear")
                }
                .buttonStyle(.bordered)

            case .connecting:
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.hippoPrimary)
                Text("연결 중...")
                    .font(.headline)

                Button {
                    onSettingsPressed()
                } label: {
                    Label("연결 설정", systemImage: "gear")
                }
                .buttonStyle(.bordered)

            case .connected:
                EmptyView()

            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.red)
                Text("연결 실패")
                    .font(.headline)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button {
                    onSettingsPressed()
                } label: {
                    Label("연결 설정 확인", systemImage: "gear")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

#Preview {
    VStack(spacing: 20) {
        ConnectionOverlay(status: .discovering, onSettingsPressed: {})
        ConnectionOverlay(status: .connecting, onSettingsPressed: {})
        ConnectionOverlay(status: .failed("테스트 에러 메시지"), onSettingsPressed: {})
    }
}
