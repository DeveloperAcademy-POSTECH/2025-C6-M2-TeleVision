import Foundation
import Observation

/// 환자 상세 화면의 ViewModel
/// MacRootViewModel의 데이터를 재사용하여 환자 정보 제공
@MainActor
@Observable
public final class PatientDetailViewModel {
    private let rootVM: MacRootViewModel

    public init(rootVM: MacRootViewModel) {
        self.rootVM = rootVM
    }
    
    public var operationCardDisplayModel = OperationCardDisplayModel()

    // MARK: - Computed Properties (rootVM 재사용)

    /// 현재 선택된 환자
    public var patient: PatientDisplayModel? {
        rootVM.selectedPatient
    }

    /// 선택된 환자의 수술 목록
    public var operations: [OperationDisplayModel] {
        rootVM.selectedPatientOperations
    }

    // MARK: - Actions (rootVM 위임)

    /// 환자 삭제
    public func deletePatient() async {
        guard let patientID = patient?.id else { return }
        await rootVM.deletePatient(patientID)
    }

    /// 수술 삭제
    public func deleteOperation(_ operationID: String) async {
        await rootVM.deleteOperation(operationID: operationID)
    }
    
    /// 데이터 새로고침
    public func refresh() async {
        await rootVM.load()
    }
}

extension PatientDetailViewModel {
    public var operationCards: [OperationCardDisplayModel] {
        guard let patient = patient else { return [] }
        return operations.map { op in
            OperationCardDisplayModel(
                id: op.id,
                patientId: patient.id,
                name: nil,
                gender: nil,
                birthDate: nil,
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
}
