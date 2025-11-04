import Foundation

// MARK: - Operation Asset Display Model

/// View 레이어 전용 OperationAsset 모델
public struct OperationAssetDisplayModel: Identifiable, Equatable, Sendable {
    public let id: String
    public let fileName: String
    public let fileURL: URL
    public let createdAt: Date

    /// 도메인 모델(OperationAsset)로부터 DisplayModel을 생성하는 매퍼(Mapper)
    public init(id: String, fileName: String, createdAt: Date, fileURL: URL) {
        self.id = id
        self.fileName = fileName
        self.createdAt = createdAt
        self.fileURL = fileURL
    }
}

// public extension OperationAssetDisplayModel {
//    func getBookmarkData() -> Data? {
//        // URL로부터 Bookmark Data를 생성하는 로직
//        guard fileURL.startAccessingSecurityScopedResource() else {
//            print("보안 리소스 접근 실패 (북마크 생성용): \(fileURL)")
//            return nil
//        }
//
//        defer {
//            fileURL.stopAccessingSecurityScopedResource()
//        }
//
//        do {
//            // ⭐️ 핵심: 북마크 데이터 생성
//            let bookmarkData = try fileURL.bookmarkData(
//                options: .minimalBookmark, // 앱 재설치 후에도 유지하려면 이 옵션
//                includingResourceValuesForKeys: nil,
//                relativeTo: nil
//            )
//
//            return bookmarkData
//
//        } catch {
//            print("북마크 생성 실패: \(error.localizedDescription)")
//            return nil
//        }
//    }
// }
