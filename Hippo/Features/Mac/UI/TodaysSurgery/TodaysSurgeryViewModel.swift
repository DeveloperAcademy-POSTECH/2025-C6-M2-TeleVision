//
//  TodaysSurgeryViewModel.swift
//  HippoMac
//
//  Created by OneThing on 11/6/25.
//

import Foundation
import Observation

/// 오늘의 수술 화면의 ViewModel
/// MacRootViewModel의 데이터를 재사용하여 오늘의 수술 정보 제공
@MainActor
@Observable
public final class TodaysSurgeryViewModel {
    private let rootVM: MacRootViewModel

    public init(rootVM: MacRootViewModel) {
        self.rootVM = rootVM
    }

    // MARK: - Computed Properties (rootVM 재사용)

    /// 오늘의 수술 목록
    public var todayOperations: [(patient: PatientDisplayModel, operation: OperationDisplayModel)] {
        rootVM.homeViewModel.todayOperations
    }

    /// 로딩 상태
    public var isLoading: Bool {
        rootVM.homeViewModel.state.isLoading
    }

    /// 에러 메시지
    public var alert: String? {
        rootVM.homeViewModel.state.alert
    }

    // MARK: - Actions (rootVM 위임)

    /// 데이터 새로고침
    public func refresh() async {
        await rootVM.load()
    }
}
