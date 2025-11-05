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
    @Dependency(\.getPatient) private var getPatient

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

    @ObservationIgnored
    @Dependency(\.getTodayOperations) private var getTodayOperations

    // MARK: - State

    public var state = PatientState()

    // Today's operations state
    public var todayOperations: [(patient: PatientDisplayModel, operation: OperationDisplayModel)] = []

    // MARK: - UI State

    public var isPresentingCreatePatientSheet: Bool = false
    public var isShowDismissAlert: Bool = false

    public var isPresentingOperationInput = false
    public var isShowingEditSheet = false

    public var patientNumber: String = ""
    public var name: String = ""
    public var birthDate: Date = .init()
    public var selectedGender: Gender = .male

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.television.hippo", category: "HomeViewModel")

    public init() {}

    /// 환자 편집을 위한 초기화
    public init(patient: PatientDisplayModel) {
        patientNumber = patient.patientNumber
        name = patient.name
        selectedGender = patient.gender
        birthDate = patient.birthDate
    }

    // MARK: - Actions

    public func load() async {
        _state.isLoading = true
        _state.alert = nil

        do {
            // Load patients
            let patients = try await listPatients.run()
            logger.debug("Loaded \(patients.count) patients from repository")

            let displayModels = patients.map { $0.toDisplayModel() }
            _state.items = displayModels

            let itemCount = _state.items.count
            logger.info("State updated with \(itemCount) items")

            // Load today's operations
            let operationsWithPatient = try await getTodayOperations.run()
            todayOperations = operationsWithPatient.map { owp in
                (patient: owp.patient.toDisplayModel(), operation: owp.operation.toDisplayModel())
            }
            logger.debug("Loaded \(self.todayOperations.count) today's operations")
        } catch {
            logger.error("Failed to load data: \(error.localizedDescription)")
            _state.alert = "Failed to load data: \(error.localizedDescription)"
        }

        _state.isLoading = false
    }

    // 환자 로드
    public func load(patientID: String) async {
        state.isLoading = true

        do {
            let p = try await getPatient.run(patientID)
            logger.debug("🐛 Loaded \(p.name) from repository")

            state.selectedPatient = p.toDisplayModel()
            state.isLoading = false

        } catch {
            logger.error("Failed to load patient with ID \(patientID), error: \(error.localizedDescription)")
            state.isLoading = false
        }
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

    // MARK: - InputView Actions

    public func loadPatientInfoToInputView() async {
        if let patient = state.selectedPatient {
            patientNumber = patient.patientNumber
            name = patient.name
            birthDate = patient.birthDate
            selectedGender = patient.gender
        }
    }

    public func deleteCurrentPatient() async {
        guard let patient = state.selectedPatient else { return }

        state.isLoading = true

        do {
            try await deletePatient.run(patient.id)
            logger.debug("🗑️ Deleted patient \(patient.name)")
            state.selectedPatient = nil
            state.isLoading = false

        } catch {
            logger.error("Failed to delete patient \(patient.id), error: \(error.localizedDescription)")
            state.isLoading = false
        }
    }

    func handleSubmit(mode: PatientInputMode) {
        Task {
            switch mode {
            case .create:
                await create(
                    patientNumber: patientNumber,
                    name: name,
                    gender: selectedGender,
                    birthDate: birthDate
                )

            case .edit:
                await update(
                    patientID: state.selectedPatient?.id ?? "",
                    patientNumber: patientNumber,
                    name: name,
                    gender: selectedGender,
                    birthDate: birthDate
                )
            }

            resetInputFields()
        }
    }

    func resetInputFields() {
        patientNumber = ""
        name = ""
        birthDate = .init()
        selectedGender = .male
    }

    // MARK: - Operation Management

    public func addOperation(
        toPatientID patientID: String,
        title: String,
        diagnosis: String,
        surgeon: String,
        surgicalSite: String,
        date: Date,
        details: String = "",
        status: OperationStatus = .planned
    ) async {
        do {
            let command = try CreateOperationCommand(
                title: title,
                diagnosis: diagnosis,
                surgeon: surgeon,
                surgicalSite: surgicalSite,
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
        fileURL: URL
    ) async {
        do {
            let command = try AttachAssetCommand(
                name: name,
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
