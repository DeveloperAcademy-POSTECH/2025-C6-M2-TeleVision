import Foundation
import Observation
import os.log

/// Mac 앱 전체의 루트 ViewModel
/// Shared ViewModel을 재사용하고 Mac 전용 네비게이션 상태만 관리
@MainActor
@Observable
public final class MacRootViewModel {
    // MARK: - Logger

    private let logger = Logger(subsystem: "com.television.hippo.mac", category: "MacRootViewModel")

    // MARK: - Navigation State

    /// Mac 네비게이션 상태
    public var navigationState = MacNavigationState()

    // MARK: - Input Form States

    /// 환자 입력 폼 상태
    public var patientInputState = PatientInputState()

    /// 수술 입력 폼 상태
    public var operationInputState = OperationInputState()

    // MARK: - Shared ViewModels (비즈니스 로직)

    /// Home 화면 ViewModel (Shared 재사용)
    public let homeViewModel: HomeViewModel

    /// Operation ViewModel (Shared 재사용)
    public var operationViewModel: OperationViewModel?

    // MARK: - Initialization

    public init() {
        self.homeViewModel = HomeViewModel()
        logger.debug("MacRootViewModel initialized with Shared ViewModels")
    }

    // MARK: - Navigation Actions
    
    /// 현재 뷰가 오늘의 수술 화면인지 여부
    public var isTodaysSurgerySelected: Bool { navigationState.isTodaysSurgerySelected }

    /// 오늘의 수술 화면으로 이동
    public func selectTodaysSurgery() {
        navigationState.selectTodaysSurgery()
        logger.debug("Selected Today's Surgery view")
    }

    /// 환자 선택
    public func selectPatient(_ patientID: String) {
        navigationState.selectPatient(patientID)
        logger.debug("Selected patient: \(patientID)")
    }
    
    /// 환자 생성 시트 열기
    public func openPatientCreateSheet() {
        navigationState.openPatientCreateSheet()
        patientInputState.reset()
        logger.debug("Opening patient create sheet")
    }
    
    /// 환자 수정 시트 열기
    public func openPatientEditSheet(patient: PatientDisplayModel) {
        navigationState.openPatientEditSheet(patient: patient)
        patientInputState = PatientInputState(from: patient)
        logger.debug("Opening patient edit sheet for: \(patient.name)")
    }

    /// 수술 생성 시트 열기
    public func openOperationCreateSheet() {
        guard let patientID = navigationState.selectedPatientID else {
            logger.warning("Cannot open operation sheet: no patient selected")
            return
        }
        navigationState.openOperationCreateSheet()
        operationInputState.reset()
        logger.debug("Opening operation create sheet for patient: \(patientID)")
    }

    /// 환자 입력 시트 닫기
    public func closePatientInputSheet() {
        navigationState.closePatientInputSheet()
        patientInputState.reset()
        logger.debug("Closed patient input sheet")
    }

    /// 수술 입력 시트 닫기
    public func closeOperationInputSheet() {
        navigationState.closeOperationInputSheet()
        operationInputState.reset()
        logger.debug("Closed operation input sheet")
    }

    // MARK: - Patient Actions (Shared ViewModel 위임)

    /// 환자 생성
    public func createPatient() async -> Bool {
        await homeViewModel.create(
            patientNumber: patientInputState.patientNumber,
            name: patientInputState.name,
            gender: patientInputState.selectedGender,
            birthDate: patientInputState.birthDate
        )

        // state.alert로 성공 여부 판단
        if homeViewModel.state.alert == nil {
            closePatientInputSheet()
            logger.debug("Patient created successfully")
            return true
        } else {
            patientInputState.errorMessage = homeViewModel.state.alert
            logger.error("Failed to create patient")
            return false
        }
    }

    /// 환자 수정
    public func updatePatient() async -> Bool {
        guard let patientID = navigationState.patientToEdit?.id else {
            logger.error("Cannot update: no patient to edit")
            return false
        }

        await homeViewModel.update(
            patientID: patientID,
            patientNumber: patientInputState.patientNumber,
            name: patientInputState.name,
            gender: patientInputState.selectedGender,
            birthDate: patientInputState.birthDate
        )

        // HomeViewModel은 void를 반환하므로 state.alert로 성공 여부 판단
        if homeViewModel.state.alert == nil {
            closePatientInputSheet()
            logger.debug("Patient updated successfully")
            return true
        } else {
            patientInputState.errorMessage = homeViewModel.state.alert
            logger.error("Failed to update patient")
            return false
        }
    }

    /// 환자 삭제
    public func deletePatient(_ patientID: String) async {
        await homeViewModel.remove(patientID: patientID)
        logger.debug("Patient deleted")
    }

    // MARK: - Operation Actions (Shared ViewModel 위임)

    /// 수술 생성
    public func createOperation() async -> Bool {
        guard let patientID = navigationState.selectedPatientID else {
            logger.error("Cannot create operation: no patient selected")
            return false
        }

        // DisplayModel을 Domain OperationAsset으로 변환
        let operationAssets = operationInputState.assets.map { $0.toDomain() }

        await homeViewModel.addOperation(
            toPatientID: patientID,
            title: operationInputState.title,
            diagnosis: operationInputState.diagnosis,
            surgeon: operationInputState.surgeon,
            surgicalSite: operationInputState.surgicalSite,
            date: operationInputState.operationDate,
            details: operationInputState.details,
            status: .planned
        )

        // HomeViewModel은 void를 반환하므로 state.alert로 성공 여부 판단
        if homeViewModel.state.alert == nil {
            closeOperationInputSheet()
            logger.debug("Operation created successfully")
            return true
        } else {
            operationInputState.errorMessage = homeViewModel.state.alert
            logger.error("Failed to create operation")
            return false
        }
    }

    /// 수술 삭제
    public func deleteOperation(operationID: String) async {
        guard let patientID = navigationState.selectedPatientID else {
            logger.error("Cannot delete operation: no patient selected")
            return
        }

        await homeViewModel.removeOperation(operationID: operationID, fromPatientID: patientID)
        logger.debug("Operation deleted")
    }

    // MARK: - Data Loading

    /// 전체 데이터 로드
    public func load() async {
        await homeViewModel.load()
        logger.debug("Loaded all data")
    }

    /// 특정 환자 로드
    public func loadPatient(_ patientID: String) async {
        await homeViewModel.load(patientID: patientID)
        logger.debug("Loaded patient: \(patientID)")
    }

    // MARK: - Computed Properties

    /// 현재 선택된 환자 정보
    public var selectedPatient: PatientDisplayModel? {
        guard let patientID = navigationState.selectedPatientID else { return nil }
        return homeViewModel.state.items.first { $0.id == patientID }
    }

    /// 선택된 환자의 수술 목록
    public var selectedPatientOperations: [OperationDisplayModel] {
        selectedPatient?.operations ?? []
    }
    
    /// 로드된 전체 환자 목록
    public var loadedPatients: [PatientDisplayModel] {
        homeViewModel.state.items
    }
}

