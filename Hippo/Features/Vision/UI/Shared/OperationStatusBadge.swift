//
//  OperationStatusBadge.swift
//  Hippo
//
//  Created by 김현기 on 10/28/25.
//

import SwiftUI

/// 텍스트와 배경색을 받아 캡슐 형태의 배지를 표시하는
struct OperationStatusBadge: View {
    // MARK: - Inputs (의존성 최소화)

    let status: String
    let color: String

    // (선택 사항) 텍스트 색상도 커스텀할 수 있게
    // 기본값을 지정하여 Input으로 뺄 수 있습니다.
    var textColor: Color = .primary

    var body: some View {
        Text(status)
            .font(.headline)
            .fontWeight(.bold)
            .foregroundStyle(textColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color(color))
            )
    }
}

// MARK: - Preview (독립적 테스트)

#Preview {
    VStack(spacing: 16) {
        // 컴포넌트가 ViewModel이나 'operation' 객체 없이도
        // 완벽하게 렌더링되는지 테스트합니다.

        OperationStatusBadge(status: "수술 중", color: "HippoPrimary")
        OperationStatusBadge(status: "대기 중", color: "HippoPrimary", textColor: .
            white)
    }
    .padding()
}
