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
    
    /// 수술 삭제
    public func deleteOperation(_ operationID: String) async {
        await rootVM.deleteOperation(operationID: operationID)
    }
    
    /// 데이터 새로고침
    public func refresh() async {
        await rootVM.load()
    }
}

extension TodaysSurgeryViewModel {
    public var operationCards: [OperationCardDisplayModel] {
        todayOperations.map { pair in
            let patient = pair.patient
            let op = pair.operation
            return OperationCardDisplayModel(
                id: op.id,
                patientId: patient.id,
                name: patient.name,
                gender: patient.genderText,
                birthDate: patient.birthDate,
                title: op.title,
                diagnosis: op.diagnosis,
                surgeon: op.surgeon,
                surgicalSite: op.surgicalSite,
                operationDate: op.date,
                details: op.details,
                assets: op.assets
            )
        }
    }
    
    /// 수술 카드 수정
    public func updateOperationCard(_ operationID: String, in patientID: String) async {
        await rootVM.operationViewModel.updateOperation()
    }
    
    /// 수술 카드 수정 시트 열기
    public func openOperationEditSheet(operation: OperationDisplayModel) async {
        rootVM.openOperationEditSheet(operation: operation)
    }
    
    /// 수술 카드 삭제
    public func deleteOperationCard(_ operationID: String, in patientID: String) async {
        await rootVM.homeViewModel.removeOperation(operationID: operationID, fromPatientID: patientID)
    }
}
