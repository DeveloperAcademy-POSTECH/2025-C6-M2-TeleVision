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
}
