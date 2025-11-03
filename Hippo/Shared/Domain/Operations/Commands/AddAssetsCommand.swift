//
//  AddAssetsCommand.swift
//  Hippo
//
//  Created by 김현기 on 11/2/25.
//

import Foundation

public struct AddAssetsCommand: Sendable {
    public let fileURLs: [URL]

    public init(fileURLs: [URL]) {
        self.fileURLs = fileURLs
    }

    public func toOperationAssetList() -> [OperationAsset] {
        fileURLs.map { url in
            OperationAsset(
                id: UUID().uuidString,
                name: url.lastPathComponent,
                fileURL: url,
                createdAt: Date()
            )
        }
    }
}
