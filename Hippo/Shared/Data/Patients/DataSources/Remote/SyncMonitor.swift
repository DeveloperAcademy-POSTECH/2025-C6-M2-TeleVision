//
//  SyncMonitor.swift
//  Hippo
//
//  Created by 김현기 on 11/21/25.
//

import CoreData
import Observation
import SwiftUI

@Observable
public class SyncMonitor {
    var isSyncing = false
    var dataDidChange = false // 데이터 변경 플래그

    init() {
        // 1. 네트워크 상태 모니터링 (기존 코드 유지 - 로딩바 표시용)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveCloudKitEvent(_:)),
            name: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil
        )
    }

    // 네트워크 이벤트 처리 (인디케이터용 + 상세 로깅)
    @objc private func didReceiveCloudKitEvent(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else { return }

        Task { @MainActor in
            let eventType = event.type == .import ? "⬇️ [받기]" : "⬆️ [보내기]"

            if event.endDate == nil {
                self.isSyncing = true
            } else {
                // 종료
                if let error = event.error {
                    print("\(eventType) CloudKit Sync Failed: \(error.localizedDescription)")
                } else {
                    print("\(eventType) CloudKit Sync Finished Successfully")

                    // Import가 성공적으로 끝났다면 데이터가 변경되었을 가능성이 높으므로 리프레시 트리거
                    if event.type == .import {
                        self.dataDidChange = true
                    }
                }
                self.isSyncing = false
            }
        }
    }

    func resetDataChangeFlag() {
        dataDidChange = false
    }
}
