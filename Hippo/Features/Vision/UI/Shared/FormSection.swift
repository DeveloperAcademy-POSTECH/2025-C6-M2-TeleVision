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
    var addAction: (() -> Void)?

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                HStack {
                    Text(title)
                        .font(.title3)
                        .foregroundStyle(.primary)

                    Spacer()

                    if let addAction {
                        Button(action: addAction) {
                            Image(systemName: "plus")
                                .font(.title3)
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            content
                .onTapGesture {
                    if let addAction {
                        addAction()
                    }
                }
        }
    }
}

extension FormSection {
    func title(_ title: String) -> FormSection {
        var copy = self
        copy.title = title
        return copy
    }

    func addAction(_ action: @escaping () -> Void) -> FormSection {
        var copy = self
        copy.addAction = action
        return copy
    }
}
