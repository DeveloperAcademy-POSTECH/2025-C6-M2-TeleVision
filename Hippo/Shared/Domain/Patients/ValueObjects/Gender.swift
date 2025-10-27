import Foundation

/// Gender value object
public enum Gender: String, Codable, Sendable, CaseIterable, Identifiable {
    case male
    case female

    public var id: Self { self }
}
