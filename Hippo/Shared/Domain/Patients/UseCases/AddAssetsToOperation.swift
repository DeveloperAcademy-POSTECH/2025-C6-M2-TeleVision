//
//  AddAssetsToOperation.swift
//  Hippo
//
//  Created by 김현기 on 11/1/25.
//

import Dependencies
import Foundation

public struct AddAssetsToOperation: Sendable {
    private let repository: PatientRepository

    public init(repository: PatientRepository) {
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

    public func run(_ input: Input) async throws {
        // 1. 파일을 영구 저장소로 복사
//        let savedAssets = try await saveFilesToDocuments(input.command.fileURLs)

        // 2. OperationAsset 생성
        let assets = input.command.fileURLs.map { url in
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

//    private func saveFilesToDocuments(_ urls: [URL]) async throws -> [URL] {
//        let fileManager = FileManager.default
//        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
//        let operationAssetsFolder = documentsURL.appendingPathComponent("OperationAssets", isDirectory: true)
//
//        // 폴더 생성
//        if !fileManager.fileExists(atPath: operationAssetsFolder.path) {
//            try fileManager.createDirectory(at: operationAssetsFolder, withIntermediateDirectories: true)
//        }
//
//        var savedURLs: [URL] = []
//
//        for url in urls {
//            // 파일명 중복 방지를 위해 UUID 추가
//            let fileExtension = url.pathExtension
//            let fileName = "\(UUID().uuidString).\(fileExtension)"
//            let destinationURL = operationAssetsFolder.appendingPathComponent(fileName)
//
//            // 기존 파일이 있으면 삭제
//            if fileManager.fileExists(atPath: destinationURL.path) {
//                try fileManager.removeItem(at: destinationURL)
//            }
//
//            // 파일 복사
//            try fileManager.copyItem(at: url, to: destinationURL)
//            savedURLs.append(destinationURL)
//        }
//
//        return savedURLs
//    }
}
