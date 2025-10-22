import Foundation
// import RealityKit

public protocol AnchorServicing {
    func attach(entityID: String, to anchorID: String) async throws
    func detach(entityID: String) async throws
}

public enum RuntimeError: Error {
    case entityNotFound(String)
    case anchorNotFound(String)
    case sceneUnavailable
}

public final class RealityAnchorService: AnchorServicing {
    public init() {}
    public func attach(entityID: String, to anchorID: String) async throws {
        // TODO: anchor.addChild(entity)
    }
    public func detach(entityID: String) async throws {
        // TODO: entity.removeFromParent()
    }
}
