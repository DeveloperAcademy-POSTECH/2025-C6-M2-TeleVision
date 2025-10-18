import Foundation

// MARK: - Legacy JSON Local Data Source (READ / IMPORT ONLY)

/// Legacy JSON Local Data Source (READ / IMPORT ONLY)
/// Location: DataSources/Local/JSON
/// ⚠️ For migrating and seeding JSON data from pre-SwiftData versions only.
/// ⚠️ The single source of truth for runtime local storage is SwiftData.
///
/// This data source is read-only. Any write operations will throw errors.
/// Use this only for importing legacy data into SwiftData.
@MainActor
public final class PatientLocalDataSourceLegacyJSON: PatientLocalDataSource {
  private let jsonURL: URL
  private let decoder: JSONDecoder

  public init(jsonURL: URL) {
    self.jsonURL = jsonURL
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    self.decoder = decoder
  }

  // MARK: - Read Operations (Supported)

  public func listPatients() throws -> [Patient] {
    let data = try Data(contentsOf: jsonURL)
    return try decoder.decode([Patient].self, from: data)
  }

  public func getPatient(id: String) throws -> Patient? {
    try listPatients().first { $0.id == id }
  }

  // MARK: - Write Operations (Not Supported - Legacy is Read-Only)

  public func upsert(_ patient: Patient) throws {
    throw NSError(
      domain: "LegacyJSON",
      code: 9001,
      userInfo: [
        NSLocalizedDescriptionKey: "Legacy JSON is read-only. Import into SwiftData instead."
      ]
    )
  }

  public func deletePatient(id: String) throws {
    throw NSError(
      domain: "LegacyJSON",
      code: 9002,
      userInfo: [
        NSLocalizedDescriptionKey: "Legacy JSON is read-only. Import into SwiftData instead."
      ]
    )
  }
}
