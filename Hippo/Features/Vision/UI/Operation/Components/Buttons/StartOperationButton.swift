//
//  StartOperationButton.swift
//  HippoVision
//
//  Created by 김현기 on 10/24/25.
//

import SwiftUI

/// 수술 시작 버튼
struct StartOperationButton: View {
    let action: () async -> Void

    var body: some View {
        Button {
            Task {
                await action()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "scissors")
                    .font(.title2)

                Text("수술 시작")
                    .font(.title3)
                    .fontWeight(.medium)
            }
            .padding(8)
        }
    }
}

#Preview {
    StartOperationButton {}
}
