import Foundation
// import RealityKit  // 실제 탐색 시 주입

public protocol EntityLocating {
    func findEntityID(named name: String) async throws -> String
}

public final class RealityEntityLocator: EntityLocating {
    public init() {}
    public func findEntityID(named name: String) async throws -> String {
        // TODO: RealityKit로 실제 엔티티 탐색 후 필요한 정보(ID) 반환
        return name
    }
}
