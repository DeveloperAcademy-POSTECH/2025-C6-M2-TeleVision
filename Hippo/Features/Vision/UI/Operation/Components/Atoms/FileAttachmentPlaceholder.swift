//
//  FileAttachmentPlaceholder.swift
//  Hippo
//
//  Created by 김현기 on 11/1/25.
//

import SwiftUI

/// 파일 첨부 영역의 빈 상태를 표시하는 Atom 컴포넌트
struct FileAttachmentPlaceholder: View {
    let message: String
    let iconName: String

    init(
        message: String = "USDZ 파일을 첨부해주세요",
        iconName: String = "cube.transparent"
    ) {
        self.message = message
        self.iconName = iconName
    }

    var body: some View {
        HStack {
            Spacer()

            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(.secondary)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(height: 150)
    }
}

#Preview {
    FileAttachmentPlaceholder()
}
