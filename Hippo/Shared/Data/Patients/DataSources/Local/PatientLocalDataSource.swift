import Foundation

/// Local data source for Patient data using JSON file storage
/// TODO: Consider migrating to SwiftData for better performance and querying capabilities
public protocol PatientLocalDataSource: Sendable {
    func fetchAll() async throws -> [Patient]
    func saveAll(_ patients: [Patient]) async throws
}

// MARK: - JSON Implementation
public actor PatientLocalDataSourceJSON: PatientLocalDataSource {
    private let storageURL: URL

    // Init performs FileManager path lookups and directory creation.
    // FileManager is not stored since it's not Sendable - we use FileManager.default directly
    public init(fileManager: FileManager = .default) {
        // Store in Application Support directory
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("Hippo", isDirectory: true)

        // Create directory if needed
        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        self.storageURL = appDirectory.appendingPathComponent("patients.json")
    }

    public func fetchAll() async throws -> [Patient] {
        // Use FileManager.default directly instead of storing it
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return []
        }

        let data = try Data(contentsOf: storageURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Patient].self, from: data)
    }

    public func saveAll(_ patients: [Patient]) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(patients)
        try data.write(to: storageURL, options: .atomic)
    }
}

// TODO: SwiftData Implementation
// Uncomment and implement when migrating to SwiftData:
//
// import SwiftData
//
// public actor PatientLocalDataSourceSwiftData: PatientLocalDataSource {
//     private let modelContainer: ModelContainer
//     private let modelContext: ModelContext
//
//     public init() throws {
//         let schema = Schema([PatientModel.self])
//         let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
//         self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
//         self.modelContext = ModelContext(modelContainer)
//     }
//
//     public func fetchAll() async throws -> [Patient] {
//         let descriptor = FetchDescriptor<PatientModel>()
//         let models = try modelContext.fetch(descriptor)
//         return models.map { $0.toDomain() }
//     }
//
//     public func saveAll(_ patients: [Patient]) async throws {
//         // Implementation here
//     }
// }
