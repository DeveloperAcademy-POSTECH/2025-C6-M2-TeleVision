import Foundation
import SwiftData

// MARK: - PatientLocalDataSourceSwiftData (SSOT Implementation)

/// SwiftData-based local data source - Single Source of Truth for local storage
/// Implements full CRUD operations on SwiftData models
@MainActor
public final class PatientLocalDataSourceSwiftData: PatientLocalDataSource {
  private let container: ModelContainer
  private let context: ModelContext

  public init(container: ModelContainer) {
    self.container = container
    self.context = ModelContext(container)
  }

  // MARK: - PatientLocalDataSource Implementation

  public func listPatients() throws -> [Patient] {
    var fetchDescriptor = FetchDescriptor<SDPatient>()
    fetchDescriptor.sortBy = [SortDescriptor(\.updatedAt, order: .reverse)]
    let sdPatients = try context.fetch(fetchDescriptor)
    return sdPatients.map { Patient.fromSwiftData($0) }
  }

  public func getPatient(id: String) throws -> Patient? {
    let predicate = #Predicate<SDPatient> { $0.id == id }
    var fetchDescriptor = FetchDescriptor<SDPatient>(predicate: predicate)
    fetchDescriptor.fetchLimit = 1
    return try context.fetch(fetchDescriptor).first.map { Patient.fromSwiftData($0) }
  }

  public func upsert(_ patient: Patient) throws {
    // Enforce unique patientNumber constraint manually
    // (SwiftData doesn't support composite unique constraints well)
    if let duplicate = try findByPatientNumber(patient.patientNumber),
       duplicate.id != patient.id {
      throw NSError(
        domain: "SwiftData",
        code: 9101,
        userInfo: [NSLocalizedDescriptionKey: "Duplicated patientNumber: \(patient.patientNumber)"]
      )
    }

    // Check if patient already exists
    let predicate = #Predicate<SDPatient> { $0.id == patient.id }
    var fetchDescriptor = FetchDescriptor<SDPatient>(predicate: predicate)
    fetchDescriptor.fetchLimit = 1

    if let existing = try context.fetch(fetchDescriptor).first {
      // Update existing patient
      existing.patientNumber = patient.patientNumber
      existing.name = patient.name
      existing.genderRaw = patient.gender.rawValue
      existing.birthDate = patient.birthDate
      existing.createdAt = patient.createdAt
      existing.updatedAt = patient.updatedAt

      // Simple rebuild of child operations (can be optimized with diffing later)
      existing.operations.forEach { context.delete($0) }
      existing.operations = patient.operations.map {
        SDOperation.fromDomain($0, owner: existing, in: context)
      }
    } else {
      // Insert new patient
      let sdPatient = SDPatient.fromDomain(patient, in: context)
      context.insert(sdPatient)
    }

    try context.save()
  }

  public func deletePatient(id: String) throws {
    let predicate = #Predicate<SDPatient> { $0.id == id }
    var fetchDescriptor = FetchDescriptor<SDPatient>(predicate: predicate)
    fetchDescriptor.fetchLimit = 1

    if let patient = try context.fetch(fetchDescriptor).first {
      context.delete(patient)
      try context.save()
    }
  }

  // MARK: - Private Helpers

  private func findByPatientNumber(_ number: String) throws -> Patient? {
    let predicate = #Predicate<SDPatient> { $0.patientNumber == number }
    var fetchDescriptor = FetchDescriptor<SDPatient>(predicate: predicate)
    fetchDescriptor.fetchLimit = 1
    return try context.fetch(fetchDescriptor).first.map { Patient.fromSwiftData($0) }
  }
}
