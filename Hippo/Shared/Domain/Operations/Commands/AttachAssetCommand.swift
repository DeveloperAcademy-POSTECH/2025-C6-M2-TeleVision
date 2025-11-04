import Foundation

/// Command object for attaching an asset to an operation
/// Encapsulates all required parameters with validation
public struct AttachAssetCommand: Sendable {
    public let name: String
    public let fileURL: URL
    public let createdAt: Date

    /// Creates a new attach asset command with validation
    /// - Parameters:
    ///   - name: Asset name (must not be empty)
    ///   - fileURL: URL to the asset file
    /// - Throws: `ValidationError` if any required field is invalid
    public init(
        name: String,
        fileURL: URL,
        createdAt: Date = Date()
    ) throws {
        // Validation
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ValidationError.emptyField("name")
        }

        self.name = name.trimmingCharacters(in: .whitespaces)
        self.fileURL = fileURL
        self.createdAt = createdAt
    }

    /// Converts command to OperationAsset entity
    /// - Returns: New OperationAsset instance with generated UUID
    public func toOperationAsset() -> OperationAsset {
        OperationAsset(
            id: UUID().uuidString,
            name: name,
            fileURL: fileURL,
            createdAt: createdAt
        )
    }
}
