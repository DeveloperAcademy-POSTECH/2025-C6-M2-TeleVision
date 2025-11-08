import Foundation
import SwiftUI


/// Mac 앱의 네비게이션 상태를 관리하는 구조체
public struct MacNavigationState {
    /// 현재 선택된 환자 ID
    public var selectedPatientID: String?
    
    /// 현재 선택된 수술 ID
    public var selectedOperationID: String?

    /// 오늘의 수술 화면 표시 여부
    public var isTodaysSurgerySelected: Bool = true

    /// 환자 입력 시트 표시 여부
    public var isPresentingPatientInput: Bool = false

    /// 수술 입력 시트 표시 여부
    public var isPresentingOperationInput: Bool = false

    /// 환자 입력 모드 (생성/수정)
    public var patientInputMode: PatientInputMode = .create
    
    /// 수술 입력 모드 (생성/수정)
    public var operationInputMode: OperationInputMode = .create

    /// 수정할 환자 정보 (수정 모드일 때)
    public var patientToEdit: PatientDisplayModel?
    
    /// 수정할 수술 정보 (수정 모드일 때)
    public var operationToEdit: OperationDisplayModel?

    public init() {}

    /// 오늘의 수술 화면으로 전환
    public mutating func selectTodaysSurgery() {
        isTodaysSurgerySelected = true
        selectedPatientID = nil
    }

    /// 환자 선택
    public mutating func selectPatient(_ patientID: String) {
        isTodaysSurgerySelected = false
        selectedPatientID = patientID
    }

    /// 환자 생성 시트 열기
    public mutating func openPatientCreateSheet() {
        patientInputMode = .create
        patientToEdit = nil
        isPresentingPatientInput = true
    }

    /// 환자 수정 시트 열기
    public mutating func openPatientEditSheet(patient: PatientDisplayModel) {
        patientInputMode = .edit
        patientToEdit = patient
        isPresentingPatientInput = true
    }

    /// 수술 생성 시트 열기
    public mutating func openOperationCreateSheet() {
        operationInputMode = .create
        operationToEdit = nil
        isPresentingOperationInput = true
    }
    
    /// 수술 수정 시트 열기. 추가됨
    public mutating func openOperationEditSheet(operation: OperationDisplayModel) {
        operationInputMode = .edit
        operationToEdit = operation
        isPresentingOperationInput = true
    }

    /// 환자 입력 시트 닫기
    public mutating func closePatientInputSheet() {
        isPresentingPatientInput = false
        patientToEdit = nil
    }

    /// 수술 입력 시트 닫기
    public mutating func closeOperationInputSheet() {
        isPresentingOperationInput = false
    }
}

extension MacNavigationState {

}
// MARK: - Patient&Operation InputMode

public enum PatientInputMode {
    case create
    case edit
}

public enum OperationInputMode {
    case create
    case edit
}
