import Foundation

/// Use Case for retrieving today's operations
public struct GetTodayOperations: Sendable {
    private let repository: OperationRepository

    public init(repository: OperationRepository) {
        self.repository = repository
    }

    /// Retrieves all operations scheduled for today
    /// Operations are sorted by status (non-completed first) and then by time
    /// - Returns: Array of OperationWithPatient sorted appropriately
    public func run() async throws -> [OperationWithPatient] {
        let operations = try await repository.getOperations(forDate: Date())

        // Sort: completed operations last, then by operation time
        return operations.sorted { lhs, rhs in
            if lhs.operation.status == .completed, rhs.operation.status != .completed {
                return false
            }
            if lhs.operation.status != .completed, rhs.operation.status == .completed {
                return true
            }
            return lhs.operation.date < rhs.operation.date
        }
    }
}
