//
//  FileAttachmentSection.swift
//  Hippo
//
//  Created by 김현기 on 11/1/25.
//

import SwiftUI
internal import UniformTypeIdentifiers

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
                    ModelFileListView(assets: selectedAssets.map { $0.toDisplayModel() })
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
            // ⭐️ [핵심 수정] ⭐️
            // 임시 URL을 즉시 OperationAsset(북마크)으로 변환한다.
            // OperationAsset.swift의 init?(url: URL)가 이 로직을 수행한다.
            let newAssets = urls.compactMap { url -> OperationAsset? in
                if let newAsset = OperationAsset(url: url) {
                    return newAsset
                } else {
                    print("Failed to create bookmark for URL: \(url.lastPathComponent)")
                    return nil
                }
            }

            // ✅ [변경 후] 변환된 Asset을 ViewModel의 상태에 추가한다.
            selectedAssets.append(contentsOf: newAssets)
            print("File import succeeded: \(newAssets.count) assets bookmarked.")

            // ❌ [변경 전] selectedFiles.append(contentsOf: urls)

        case let .failure(error):
            print("File import failed: \(error.localizedDescription)")
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
