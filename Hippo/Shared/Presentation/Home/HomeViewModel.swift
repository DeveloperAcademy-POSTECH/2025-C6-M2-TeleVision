import Dependencies
import Foundation
import Observation
import os.log

@MainActor
@Observable
public final class HomeViewModel {
    // MARK: - Dependencies

    @ObservationIgnored
    @Dependency(\.listPatients) private var listPatients

    @ObservationIgnored
    @Dependency(\.createPatient) private var createPatient

    @ObservationIgnored
    @Dependency(\.updatePatient) private var updatePatient

    @ObservationIgnored
    @Dependency(\.deletePatient) private var deletePatient

    @ObservationIgnored
    @Dependency(\.createOperation) private var createOperation

    @ObservationIgnored
    @Dependency(\.upsertOperation) private var upsertOperation

    @ObservationIgnored
    @Dependency(\.deleteOperation) private var deleteOperation

    @ObservationIgnored
    @Dependency(\.attachAssetToOperation) private var attachAssetToOperation

    @ObservationIgnored
    @Dependency(\.removeAssetFromOperation) private var removeAssetFromOperation

    // MARK: - State

    private let _state = PatientState()
    public var state: PatientState { _state } // 읽기 전용, 관찰 가능

    // MARK: - UI State

    public var patientNumber: String = ""
    public var name: String = ""
    public var birthDate: Date = .init()
    public var selectedGender: Gender = .male

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.television.hippo", category: "PatientViewModel")

    public init() {}

    // MARK: - Computed Properties

    /// 오늘 예정된 환자 목록 (시간순 정렬, 완료된 수술은 뒤로)
    public var todayPlannedPatients: [PatientDisplayModel] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return state.items
            .filter { patient in
                guard let operation = patient.latestOperation else { return false }
                let operationDay = calendar.startOfDay(for: operation.date)
                return today == operationDay
            }
            .sorted { patient1, patient2 in
                guard let op1 = patient1.latestOperation,
                      let op2 = patient2.latestOperation
                else {
                    return false
                }

                // 1. 완료된 수술은 뒤로
                if op1.status == .completed, op2.status != .completed {
                    return false
                }
                if op1.status != .completed, op2.status == .completed {
                    return true
                }

                // 2. 같은 상태면 수술 시간 오름차순 (이른 시간이 먼저)
                return op1.date < op2.date
            }
    }

    // MARK: - Actions

    public func load() async {
        _state.isLoading = true
        _state.alert = nil

        do {
            let patients = try await listPatients.run()
            logger.debug("Loaded \(patients.count) patients from repository")

            let displayModels = patients.map { $0.toDisplayModel() }
            _state.items = displayModels

            let itemCount = _state.items.count
            logger.info("State updated with \(itemCount) items")
        } catch {
            logger.error("Failed to load patients: \(error.localizedDescription)")
            _state.alert = "Failed to load patients: \(error.localizedDescription)"
        }

        _state.isLoading = false
    }

    public func create(
        patientNumber: String,
        name: String,
        gender: Gender,
        birthDate: Date
    ) async {
        do {
            let command = try CreatePatientCommand(
                patientNumber: patientNumber,
                name: name,
                gender: gender,
                birthDate: birthDate
            )

            await executeWithErrorHandling(
                operation: { [self] in
                    _ = try await self.createPatient.run(CreatePatient.Input(command: command))
                },
                errorMessage: "Failed to create patient"
            )
        } catch let validationError as ValidationError {
            logger.warning("Validation failed: \(validationError.localizedDescription)")
            _state.alert = validationError.localizedDescription
        } catch {
            logger.error("Unexpected error creating patient command: \(error.localizedDescription)")
            _state.alert = "Failed to create patient: \(error.localizedDescription)"
        }
    }

    public func update(
        patientID: String,
        patientNumber: String,
        name: String,
        gender: Gender,
        birthDate: Date
    ) async {
        do {
            let command = try UpdatePatientCommand(
                patientNumber: patientNumber,
                name: name,
                gender: gender,
                birthDate: birthDate
            )

            await executeWithErrorHandling(
                operation: { [self] in
                    _ = try await self.updatePatient.run(UpdatePatient.Input(patientID: patientID, command: command))
                },
                errorMessage: "Failed to update patient"
            )
        } catch let validationError as ValidationError {
            logger.warning("Validation failed: \(validationError.localizedDescription)")
            _state.alert = validationError.localizedDescription
        } catch {
            logger.error("Unexpected error updating patient: \(error.localizedDescription)")
            _state.alert = "Failed to update patient: \(error.localizedDescription)"
        }
    }

    public func remove(patientID: String) async {
        await executeWithErrorHandling(
            operation: { [self] in try await self.deletePatient.run(patientID) },
            errorMessage: "Failed to delete patient"
        )
    }

    // MARK: - Operation Management

    public func addOperation(
        toPatientID patientID: String,
        title: String,
        diagnosis: String,
        surgeon: String,
        date: Date,
        details: String = "",
        status: OperationStatus = .planned
    ) async {
        do {
            let command = try CreateOperationCommand(
                title: title,
                diagnosis: diagnosis,
                surgeon: surgeon,
                date: date,
                details: details,
                status: status
            )

            await executeWithErrorHandling(
                operation: { [self] in
                    try await self.createOperation.run(
                        CreateOperation.Input(patientID: patientID, command: command)
                    )
                },
                errorMessage: "Failed to add operation"
            )
        } catch let validationError as ValidationError {
            logger.warning("Validation failed: \(validationError.localizedDescription)")
            _state.alert = validationError.localizedDescription
        } catch {
            logger.error("Unexpected error creating operation command: \(error.localizedDescription)")
            _state.alert = "Failed to add operation: \(error.localizedDescription)"
        }
    }

    public func removeOperation(operationID: String, fromPatientID patientID: String) async {
        await executeWithErrorHandling(
            operation: { [self] in
                try await self.deleteOperation.run(
                    DeleteOperation.Input(patientID: patientID, operationID: operationID)
                )
            },
            errorMessage: "Failed to remove operation"
        )
    }

    // MARK: - Asset Management

    public func attachAsset(
        toOperationID operationID: String,
        inPatientID patientID: String,
        name: String,
        fileExtension: OperationAssetExtension,
        fileURL: URL
    ) async {
        do {
            let command = try AttachAssetCommand(
                name: name,
                fileExtension: fileExtension,
                fileURL: fileURL
            )

            await executeWithErrorHandling(
                operation: { [self] in
                    try await self.attachAssetToOperation.run(
                        AttachAssetToOperation.Input(
                            patientID: patientID,
                            operationID: operationID,
                            command: command
                        )
                    )
                },
                errorMessage: "Failed to attach asset"
            )
        } catch let validationError as ValidationError {
            logger.warning("Validation failed: \(validationError.localizedDescription)")
            _state.alert = validationError.localizedDescription
        } catch {
            logger.error("Unexpected error creating attach asset command: \(error.localizedDescription)")
            _state.alert = "Failed to attach asset: \(error.localizedDescription)"
        }
    }

    public func removeAsset(
        assetID: String,
        fromOperationID operationID: String,
        inPatientID patientID: String
    ) async {
        await executeWithErrorHandling(
            operation: { [self] in
                try await self.removeAssetFromOperation.run(
                    RemoveAssetFromOperation.Input(
                        patientID: patientID,
                        operationID: operationID,
                        assetID: assetID
                    )
                )
            },
            errorMessage: "Failed to remove asset"
        )
    }

    public func dismissAlert() {
        _state.alert = nil
    }

    // MARK: - Private Helpers

    private func executeWithErrorHandling(
        operation: @escaping () async throws -> Void,
        errorMessage: String
    ) async {
        do {
            try await operation()
            await load()
        } catch {
            logger.error("\(errorMessage): \(error.localizedDescription)")
            _state.alert = "\(errorMessage): \(error.localizedDescription)"
        }
    }
}
