//
//  EmptyTodaySurgeryView.swift
//  Hippo
//
//  Created by 김현기 on 11/2/25.
//

import SwiftUI

/// 오늘 수술 없음 표시
struct EmptyTodaySurgeryView: View {
    var body: some View {
        Text("오늘 예정된 수술이 없습니다")
            .foregroundStyle(.secondary)
            .font(.title2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
    }
}
