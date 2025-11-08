import Foundation
import Observation
import os.log

/// 환자 상세 화면의 ViewModel
/// MacRootViewModel의 데이터를 재사용하여 환자 정보 제공
@MainActor
@Observable
public final class PatientDetailViewModel {
    private let rootVM: MacRootViewModel
    
    private let logger = Logger(subsystem: "com.television.hippo.mac", category: "MacRootViewModel")

    public init(rootVM: MacRootViewModel) {
        self.rootVM = rootVM
    }
    
    public var isPresentingOperationInput: Bool {
        get { rootVM.navigationState.isPresentingOperationInput }
        set { rootVM.navigationState.isPresentingOperationInput = newValue }
    }

    public var operationInputMode: OperationInputMode {
        get { rootVM.navigationState.operationInputMode }
        set { rootVM.navigationState.operationInputMode = newValue}
    }
    
    public var operationInputState: OperationInputState {
        get { rootVM.operationInputState }
        set { rootVM.operationInputState = newValue }
    }
    
    public var selectedOperationID: String? {
        get { rootVM.navigationState.selectedOperationID }
        set { rootVM.navigationState.selectedOperationID = newValue }
    }

    // MARK: - Computed Properties (rootVM 재사용)

    /// 현재 선택된 환자
    public var patient: PatientDisplayModel? {
        get { rootVM.selectedPatient }
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
    
    /// 수술 수정 시트 열기. 추가됨
    public func openOperationEditSheet(operation: OperationDisplayModel) {
        rootVM.openOperationEditSheet(operation: operation)
    }
    
    /// 하위 뷰로부터 받은 ID 기반으로 수술 조회. 추가됨
    public func operation(by id: String) -> OperationDisplayModel? {
        operations.first { $0.id == id }
    }

}
