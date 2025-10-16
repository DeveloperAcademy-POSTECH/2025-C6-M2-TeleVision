import Foundation

/// State for Patient list view
public struct PatientState: Equatable, Sendable {
    public var items: [Patient]
    public var isLoading: Bool
    public var alert: String?

    public nonisolated init(
        items: [Patient] = [],
        isLoading: Bool = false,
        alert: String? = nil
    ) {
        self.items = items
        self.isLoading = isLoading
        self.alert = alert
    }
}
