//
//  LogoHeader.swift
//  HippoVision
//
//  Created by 김현기 on 10/21/25.
//

import SwiftUI

/// 앱 로고 헤더
struct LogoHeader: View {
    let syncMonitor: SyncMonitor?
    let onRefresh: (() -> Void)?

    @State private var isManualRefreshing = false

    init(
        syncMonitor: SyncMonitor? = nil,
        onRefresh: (() -> Void)? = nil
    ) {
        self.syncMonitor = syncMonitor
        self.onRefresh = onRefresh
    }

    var body: some View {
        HStack {
            Image("HippoLogo")
                .resizable()
                .frame(width: 40, height: 40)
                .scaledToFit()
                .padding(.trailing, 8)

            Text("Hippo")
                .foregroundStyle(.primary)
                .font(.extraLargeTitle2)

            Spacer()

            // 동기화 상태 표시
            if let syncMonitor = syncMonitor {
                HStack(spacing: 12) {
                    if syncMonitor.isSyncing || isManualRefreshing {
                        ProgressView()
                            .scaleEffect(0.8)

                        Text("iCloud와 연동 중...")
                            .foregroundStyle(.secondary)
                            .font(.body)
                    }

                    // 새로고침 버튼
                    Button(action: {
                        handleRefresh()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(isManualRefreshing)
                }
                .animation(.easeInOut, value: syncMonitor.isSyncing)
                .animation(.easeInOut, value: isManualRefreshing)
            }
        }
    }

    private func handleRefresh() {
        guard let onRefresh = onRefresh else { return }

        // 수동 새로고침 시작
        isManualRefreshing = true

        // 새로고침 실행
        onRefresh()

        // 1초 후 자동으로 상태 해제 (자연스러운 UX)
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            isManualRefreshing = false
        }
    }
}

#Preview {
    LogoHeader()
}
