//
//  FormSection.swift
//  Hippo
//
//  Created by 김현기 on 10/27/25.
//

import SwiftUI

/// 폼 섹션의 제목을 표시하는 재사용 가능한 헤더 뷰 (Atom)
struct FormSection<Content: View>: View {
    let content: Content

    var title: String?

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.title3)
            }

            content
        }
    }
}

extension FormSection {
    func title(_ title: String) -> FormSection {
        var copy = self
        copy.title = title
        return copy
    }
}
