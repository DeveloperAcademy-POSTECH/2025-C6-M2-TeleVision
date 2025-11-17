//
//  RecordCard.swift
//  Hippo
//
//  Created by 김현기 on 11/17/25.
//

import SwiftUI

struct RecordCard: View {
    let record: OperationRecording

    @Environment(AppModel.self) private var appModel
    @Environment(RecordingViewModel.self) private var viewModel

    private let cornerRadius = 20.0

    var body: some View {
        Button {
            viewModel.playRecord(record)
        } label: {
            VStack {
                if let data = record.thumbnailData, let thumbnail = UIImage(data: data) {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 200)
                } else {
                    // 썸네일 없으면 기본 아이콘 표시
                    Rectangle()
                        .fill(.secondary.opacity(0.3))
                    Image(systemName: "video.fill")
                        .font(.title)
                        .opacity(0.5)
                        .frame(height: 200)
                }

                Text(record.createdAt.toOperationDateString())
                    .font(.headline)
                    .lineLimit(1)
            }
            .padding()
            .background(.thinMaterial)
            .cornerRadius(cornerRadius)
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.roundedRectangle(radius: cornerRadius))
        .frame(width: 440, height: appModel.homeWindowSize.height * 0.4)
    }
}
