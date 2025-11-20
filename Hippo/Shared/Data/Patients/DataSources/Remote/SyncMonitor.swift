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
class SyncMonitor {
    var isSyncing = false

    // 동시에 발생하는 여러 이벤트를 추적하기 위한 Set
    private var activeEventIdentifiers: Set<UUID> = []
    // 상태 변경 지연을 위한 Task
    private var syncTimeoutTask: Task<Void, Error>?

    init() {
        // NSPersistentCloudKitContainer의 동기화 이벤트 알림을 구독합니다.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveCoreDataEvent(_:)),
            name: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil
        )
    }

    @objc private func didReceiveCoreDataEvent(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else { return }

        Task { @MainActor in
            if event.endDate == nil {
                // 이벤트 시작: 식별자를 추가
                activeEventIdentifiers.insert(event.identifier)

                // 새로운 이벤트가 시작되었으므로, '동기화 종료' 대기 중인 작업이 있다면 취소합니다.
                syncTimeoutTask?.cancel()
                isSyncing = true
            } else {
                // 이벤트 종료: 식별자 제거
                activeEventIdentifiers.remove(event.identifier)

                // 모든 이벤트가 종료되었는지 확인
                if activeEventIdentifiers.isEmpty {
                    // 기존 타이머 취소
                    syncTimeoutTask?.cancel()

                    // 동기화가 끝났을 때, UI가 너무 빨리 깜빡이는 것을 방지하기 위해
                    // 1초 정도 대기 후 상태를 변경합니다 (Debounce).
                    syncTimeoutTask = Task {
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1초 대기

                        // 대기 시간이 끝날 때까지 취소되지 않았다면 동기화 상태 해제
                        if !Task.isCancelled {
                            self.isSyncing = false
                        }
                    }
                }
            }
        }
    }
}
