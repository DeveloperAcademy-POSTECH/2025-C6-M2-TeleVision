//
//  ThumbnailVideoView.swift
//  Hippo
//
//  Created by 김현기 on 11/17/25.
//

import SwiftUI

/// 하단 캐로셀에 표시될 썸네일 아이템
struct ThumbnailVideoView: View {
    let recording: OperationRecording
    let isSelected: Bool

    var body: some View {
        ZStack {
            // 썸네일 데이터가 있으면 표시
            if let data = recording.thumbnailData, let thumbnail = UIImage(data: data) {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // 썸네일 없으면 기본 아이콘 표시
                Rectangle()
                    .fill(.secondary.opacity(0.3))
                Image(systemName: "video.fill")
                    .font(.title)
                    .opacity(0.5)
            }
        }
        .frame(width: 160, height: 90) // 16:9 비율
        .clipShape(RoundedRectangle(cornerRadius: 12))
        // (사진 참고) 선택되었을 때 파란색 테두리
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, lineWidth: 4)
            }
        }
        .padding(.vertical, 8)
    }
}
