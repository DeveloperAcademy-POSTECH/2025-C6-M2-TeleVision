import Foundation
import CloudKit

/// Remote data source for Patient data
public protocol PatientRemoteDataSource: Sendable {
    func pullAll() async throws -> [Patient]
    func push(_ patient: Patient) async throws
    func remove(id: String) async throws
}

// MARK: - No-op (Safe default) Implementation
/// A safe stub that performs no remote operations.
/// Use this during development before wiring up CloudKit or any backend.
public actor PatientRemoteDataSourceNoop: PatientRemoteDataSource {
    public init() {}

    public func pullAll() async throws -> [Patient] {
        // No remote; return nothing
        return []
    }

    public func push(_ patient: Patient) async throws {
        // No-op
    }

    public func remove(id: String) async throws {
        // No-op
    }
}

// MARK: - CloudKit Implementation (Stub - does not touch CloudKit yet)
/// Note: This type currently does NOT create CKContainer/CKDatabase to avoid runtime crashes
/// when iCloud/CloudKit is not configured. It behaves as a no-op until you implement it.
/// When you are ready to connect CloudKit, replace the TODOs with real logic and
/// safely initialize CKContainer/CKDatabase after entitlements and container are set up.
public actor PatientRemoteDataSourceCloudKit: PatientRemoteDataSource {
    // Intentionally not creating CKContainer/CKDatabase yet to avoid SIGABRT
    // private let container: CKContainer
    // private let database: CKDatabase

    public init(containerIdentifier: String? = nil) {
        // Defer any CloudKit initialization until configuration is ready.
        // Example (enable when CloudKit is configured):
        //
        // if let identifier = containerIdentifier {
        //     self.container = CKContainer(identifier: identifier)
        // } else {
        //     self.container = CKContainer.default()
        // }
        // self.database = container.privateCloudDatabase
    }

    public func pullAll() async throws -> [Patient] {
        // TODO: Implement CloudKit fetch when ready
        // Example:
        // let query = CKQuery(recordType: "Patient", predicate: NSPredicate(value: true))
        // var fetched: [Patient] = []
        // for try await result in database.records(matching: query) { ... }
        return []
    }

    public func push(_ patient: Patient) async throws {
        // TODO: Implement CloudKit save when ready
        // Example:
        // let record = patient.toCKRecord()
        // _ = try await database.save(record)
    }

    public func remove(id: String) async throws {
        // TODO: Implement CloudKit delete when ready
        // Example:
        // let recordID = CKRecord.ID(recordName: id)
        // _ = try await database.deleteRecord(withID: recordID)
    }
}

// TODO: CloudKit Mappers (Enable when CloudKit is configured)
// extension Patient {
//     func toCKRecord() -> CKRecord {
//         let record = CKRecord(recordType: "Patient", recordID: CKRecord.ID(recordName: id.value))
//         record["name"] = name as CKRecordValue
//         record["sex"] = sex.rawValue as CKRecordValue
//         record["birthDate"] = birthDate as? CKRecordValue
//         record["mrn"] = mrn as? CKRecordValue
//         record["updatedAt"] = updatedAt as CKRecordValue
//         return record
//     }
// }
//
// extension CKRecord {
//     func toDomain() throws -> Patient {
//         guard let name = self["name"] as? String,
//               let sexRaw = self["sex"] as? String,
//               let sex = Sex(rawValue: sexRaw),
//               let updatedAt = self["updatedAt"] as? Date else {
//             throw NSError(domain: "CloudKitMapper", code: -1)
//         }
//
//         return Patient(
//             id: PatientID(value: recordID.recordName),
//             name: name,
//             sex: sex,
//             birthDate: self["birthDate"] as? Date,
//             mrn: self["mrn"] as? String,
//             cases: [],
//             updatedAt: updatedAt
//         )
//     }
// }
