//
//  FileAttachmentSection.swift
//  Hippo
//
//  Created by 김현기 on 11/1/25.
//

import SwiftUI
internal import UniformTypeIdentifiers
import os.log

/// 파일 첨부 영역 전체를 관리하는 Organism 컴포넌트
struct FileAttachmentSection: View {
    @Binding var selectedAssets: [OperationAsset]
    @Binding var isShowingFilePicker: Bool

    var body: some View {
        FormSection {
            HStack {
                if selectedAssets.isEmpty {
                    FileAttachmentPlaceholder()
                } else {
                    ModelFileListView(assets: selectedAssets.map { $0.toDisplayModel() }, isReadOnly: false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 150)
            .background(.thinMaterial)
            .cornerRadius(12)
            .fileImporter(
                isPresented: $isShowingFilePicker,
                allowedContentTypes: [.usd, .usdz],
                allowsMultipleSelection: true
            ) { result in
                handleFileImportResult(result)
            }
        }
        .title("3D 모델 파일")
        .addAction {
            isShowingFilePicker = true
        }
    }

    private func handleFileImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            let newAssets = urls.compactMap { url -> OperationAsset? in
                if let newAsset = OperationAsset(url: url) {
                    return newAsset
                } else {
                    Logger().log("Failed to create bookmark for URL: \(url.lastPathComponent)")
                    return nil
                }
            }

            selectedAssets.append(contentsOf: newAssets)

        case let .failure(error):
            Logger().log("File import failed: \(error.localizedDescription)")
        }
    }
}

#Preview {
    @Previewable @State var selectedFiles: [OperationAsset] = []
    @Previewable @State var isShowingFilePicker = false

    FileAttachmentSection(
        selectedAssets: $selectedFiles,
        isShowingFilePicker: $isShowingFilePicker
    )
    .padding()
}
