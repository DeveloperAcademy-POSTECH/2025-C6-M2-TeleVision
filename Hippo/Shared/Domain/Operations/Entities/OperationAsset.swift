import Foundation

// MARK: - OperationAsset Entity

// Entity: lifecycle/stateful (CKAsset linkage, replacement/version possible)

/// 수술에 사용되는 3D 모델 파일 등 외부 리소스를 나타내는 도메인 엔티티.
/// CloudKit 동기화를 위해 파일 데이터 자체를 저장합니다.
public struct OperationAsset: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let fileData: Data
    public let originalFileName: String
    public var createdAt: Date

    public init?(url: URL) {
        // URL로부터 파일 데이터를 읽어서 저장
        guard url.startAccessingSecurityScopedResource() else {
            return nil
        }

        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            
            id = UUID().uuidString
            fileData = data
            originalFileName = url.lastPathComponent
            createdAt = Date()

        } catch {
            print("Failed to read file data from \(url): \(error)")
            return nil
        }
    }

    init(id: String, fileData: Data, originalFileName: String, createdAt: Date) {
        self.id = id
        self.fileData = fileData
        self.originalFileName = originalFileName
        self.createdAt = createdAt
    }
}

public extension OperationAsset {
    /// 저장된 파일 데이터를 임시 파일로 저장하고 URL을 반환합니다.
    func getResolvedURL() -> URL? {
        // 임시 디렉토리에 파일 저장
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(originalFileName)
        
        do {
            // 기존 파일이 있으면 삭제
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            
            // 파일 데이터를 임시 파일로 저장
            try fileData.write(to: fileURL)
            return fileURL
            
        } catch {
            print("Failed to write file data for \(originalFileName): \(error)")
            return nil
        }
    }
}
