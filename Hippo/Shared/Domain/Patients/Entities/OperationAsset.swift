import Foundation

// MARK: - OperationAsset Entity

// Entity: lifecycle/stateful (CKAsset linkage, replacement/version possible)

/// 수술에 사용되는 3D 모델 파일 등 외부 리소스에 대한 '영구 접근 권한'을 나타내는 도메인 엔티티.
/// 이 모델은 파일의 URL 자체가 아닌, 해당 파일에 접근할 수 있는 '보안 책갈피(Bookmark)' 데이터를 저장한다.
public struct OperationAsset: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let bookmarkData: Data
    public let originalFileName: String
    public var createdAt: Date

    public init?(url: URL) {
        // URL로부터 Bookmark Data를 생성하는 로직
        // 이 작업은 파일에 대한 임시 접근 권한이 있을 때 즉시 수행해야 함.
        guard url.startAccessingSecurityScopedResource() else {
            print("보안 리소스 접근 실패 (북마크 생성용): \(url)")
            return nil
        }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        do {
            // ⭐️ 핵심: 북마크 데이터 생성
            let bookmarkData = try url.bookmarkData(
                options: .minimalBookmark, // 앱 재설치 후에도 유지하려면 이 옵션
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            id = UUID().uuidString
            self.bookmarkData = bookmarkData
            originalFileName = url.lastPathComponent
            createdAt = Date()

        } catch {
            print("북마크 생성 실패: \(error.localizedDescription)")
            return nil
        }
    }

    init(id: String, bookmarkData: Data, originalFileName: String, createdAt: Date) {
        self.id = id
        self.bookmarkData = bookmarkData
        self.originalFileName = originalFileName
        self.createdAt = createdAt
    }
}

public extension OperationAsset {
    /// 저장된 북마크 데이터를 사용하여 파일에 접근 가능한 URL로 변환합니다.
    func getResolvedURL() -> URL? {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withoutImplicitStartAccessing, // ⭐️ 매우 중요
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                print("Bookmark is stale for \(originalFileName)")
            }

            if url.startAccessingSecurityScopedResource() {
                print("Started access for \(originalFileName)")
                return url
            } else {
                print("Failed to start security access for \(originalFileName)")
                return nil
            }

        } catch {
            print("Failed to resolve bookmark for \(originalFileName): \(error)")
            return nil
        }
    }
}
