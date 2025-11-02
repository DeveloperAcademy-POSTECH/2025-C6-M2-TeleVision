//
//  ModeFilelListView.swift
//  Hippo
//
//  Created by 김현기 on 11/1/25.
//

// Hippo/Features/Vision/UI/Operation/Components/Molecules/Model3DFileListView.swift

import SwiftUI

/// 3D 모델 파일 목록을 수평 스크롤로 표시하는 Molecule 컴포넌트
struct ModelFileListView: View {
    let fileURLs: [URL]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Spacer().frame(width: 0)

                ForEach(fileURLs, id: \.self) { url in
                    ModelPreviewCard(url: url)
                }
            }
            .padding(.vertical)
        }
        .onAppear {
            print("ModelFileListView - fileURLs: \(fileURLs)")
        }
    }
}

#Preview {
    ModelFileListView(fileURLs: [])
        .frame(height: 150)
        .background(.thinMaterial)
}
