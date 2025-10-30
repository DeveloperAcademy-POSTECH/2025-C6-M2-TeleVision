//
//  EmptyOperationView.swift
//  Hippo
//
//  Created by 김현기 on 10/30/25.
//

import SwiftUI

struct EmptyOperationView: View {
    var body: some View {
        VStack {
            Text("수술 데이터가 없습니다.")
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.bottom, 8)
            Text("수술 준비를 위해 데이터를 입력해주세요.")
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview {
    EmptyOperationView()
}
