import Foundation
import SwiftData

// MARK: - SwiftData Mappers (Domain <-> SwiftData)

// MARK: Domain -> SwiftData

extension SDPatient {
    /// Convert Domain Patient to SwiftData SDPatient
    static func fromDomain(_ p: Patient, in ctx: ModelContext) -> SDPatient {
        let sdPatient = SDPatient(
            id: p.id,
            patientNumber: p.patientNumber,
            name: p.name,
            genderRaw: p.gender.rawValue,
            birthDate: p.birthDate,
            createdAt: p.createdAt,
            updatedAt: p.updatedAt
        )
        sdPatient.operations = p.operations.map { SDOperation.fromDomain($0, owner: sdPatient, in: ctx) }
        return sdPatient
    }
}

extension SDOperation {
    /// Convert Domain Operation to SwiftData SDOperation
    static func fromDomain(_ o: Operation, owner patient: SDPatient, in _: ModelContext) -> SDOperation {
        let sdOperation = SDOperation(
            id: o.id,
            title: o.title,
            diagnosis: o.diagnosis,
            surgeon: o.surgeon,
            date: o.date,
            details: o.details,
            statusRaw: o.status.rawValue
        )
        sdOperation.patient = patient
        sdOperation.assets = o.operationAssets.map { SDOperationAsset.fromDomain($0, owner: sdOperation) }
        sdOperation.recordings = o.recordings.map { SDOperationRecording.fromDomain($0, owner: sdOperation) }
        return sdOperation
    }
}

extension SDOperationAsset {
    /// Convert Domain OperationAsset to SwiftData SDOperationAsset
    static func fromDomain(_ a: OperationAsset, owner op: SDOperation) -> SDOperationAsset {
        let sdAsset = SDOperationAsset(
            id: a.id,
            name: a.name,
            fileURL: a.fileURL.absoluteString,
            createdAt: Date()
        )
        sdAsset.operation = op
        return sdAsset
    }
}

extension SDOperationRecording {
    /// Convert Domain OperationRecording to SwiftData SDOperationRecording
    static func fromDomain(_ r: OperationRecording, owner op: SDOperation) -> SDOperationRecording {
        let sdRecording = SDOperationRecording(
            id: r.id,
            fileURLString: r.fileURL.absoluteString
        )
        sdRecording.operation = op
        return sdRecording
    }
}

// MARK: SwiftData -> Domain

extension Patient {
    /// Convert SwiftData SDPatient to Domain Patient
    @MainActor
    static func fromSwiftData(_ s: SDPatient) -> Patient {
        Patient(
            id: s.id,
            patientNumber: s.patientNumber,
            name: s.name,
            gender: Gender(rawValue: s.genderRaw) ?? .male,
            birthDate: s.birthDate,
            operations: s.operations.map(Operation.fromSwiftData),
            createdAt: s.createdAt,
            updatedAt: s.updatedAt
        )
    }
}

extension Operation {
    /// Convert SwiftData SDOperation to Domain Operation
    @MainActor
    static func fromSwiftData(_ s: SDOperation) -> Operation {
        Operation(
            id: s.id,
            title: s.title,
            diagnosis: s.diagnosis,
            surgeon: s.surgeon,
            date: s.date,
            details: s.details,
            operationAssets: s.assets.map(OperationAsset.fromSwiftData),
            recordings: s.recordings.map(OperationRecording.fromSwiftData),
            status: OperationStatus(rawValue: s.statusRaw) ?? .planned
        )
    }
}

extension OperationAsset {
    /// Convert SwiftData SDOperationAsset to Domain OperationAsset
    @MainActor
    static func fromSwiftData(_ s: SDOperationAsset) -> OperationAsset {
        OperationAsset(
            id: s.id,
            name: s.name,
            fileURL: URL(string: s.fileURL) ?? URL(fileURLWithPath: "/dev/null"),
            createdAt: s.createdAt
        )
    }
}

extension OperationRecording {
    /// Convert SwiftData SDOperationRecording to Domain OperationRecording
    @MainActor
    static func fromSwiftData(_ s: SDOperationRecording) -> OperationRecording {
        OperationRecording(
            id: s.id,
            fileURL: URL(string: s.fileURLString) ?? URL(fileURLWithPath: "/dev/null")
        )
    }
}
