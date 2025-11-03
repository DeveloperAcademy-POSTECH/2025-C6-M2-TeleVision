import Dependencies
import Foundation

/// Use Case for adding multiple assets to an operation
/// This use case handles file persistence to Documents directory
/// and saves asset metadata to the operation
public struct AddAssetsToOperation: Sendable {
    private let repository: OperationRepository

    public init(repository: OperationRepository) {
        self.repository = repository
    }

    public struct Input: Sendable {
        public let patientID: String
        public let operationID: String
        public let command: AddAssetsCommand

        public init(patientID: String, operationID: String, command: AddAssetsCommand) {
            self.patientID = patientID
            self.operationID = operationID
            self.command = command
        }
    }

    /// Adds multiple assets to an operation
    /// - Parameter input: Input containing patient ID, operation ID, and assets command
    /// - Throws: OperationError.operationNotFound if operation doesn't exist
    /// - Throws: OperationError.patientNotFound if patient doesn't exist
    public func run(_ input: Input) async throws {
        // 1. 파일을 영구 저장소로 복사 (Mac Sandbox 보안 스코프 처리 포함)
        let savedAssets = try await saveFilesToDocuments(input.command.fileURLs)

        // 2. OperationAsset 생성
        let assets = savedAssets.map { url in
            OperationAsset(
                name: url.deletingPathExtension().lastPathComponent,
                fileURL: url,
                createdAt: Date()
            )
        }

        // 3. Repository를 통해 저장
        try await repository.addAssets(
            assets,
            toOperationID: input.operationID,
            inPatientID: input.patientID
        )
    }

    private func saveFilesToDocuments(_ urls: [URL]) async throws -> [URL] {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let operationAssetsFolder = documentsURL.appendingPathComponent("OperationAssets", isDirectory: true)

        // 폴더 생성
        if !fileManager.fileExists(atPath: operationAssetsFolder.path) {
            try fileManager.createDirectory(at: operationAssetsFolder, withIntermediateDirectories: true)
        }

        var savedURLs: [URL] = []

        for url in urls {
            // 보안 스코프 리소스 접근
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            // 파일명 중복 방지를 위해 UUID 추가
            let fileExtension = url.pathExtension
            let fileName = "\(url.deletingPathExtension().lastPathComponent).\(fileExtension)"
            let destinationURL = operationAssetsFolder.appendingPathComponent(fileName)

            // 기존 파일이 있으면 삭제
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            // 파일 복사
            try fileManager.copyItem(at: url, to: destinationURL)
            savedURLs.append(destinationURL)
        }

        return savedURLs
    }
}
