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
    @Binding var selectedFiles: [URL]
    @Binding var isShowingFilePicker: Bool

    var body: some View {
        FormSection {
            HStack {
                if selectedFiles.isEmpty {
                    FileAttachmentPlaceholder()
                } else {
                    ModelFileListView(fileURLs: selectedFiles)
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
            selectedFiles.append(contentsOf: urls)
            print("File import succeeded: \(urls)")

        case let .failure(error):
            print("File import failed: \(error.localizedDescription)")
        }
    }
}

#Preview {
    @Previewable @State var selectedFiles: [URL] = []
    @Previewable @State var isShowingFilePicker = false

    FileAttachmentSection(
        selectedFiles: $selectedFiles,
        isShowingFilePicker: $isShowingFilePicker
    )
    .padding()
}
