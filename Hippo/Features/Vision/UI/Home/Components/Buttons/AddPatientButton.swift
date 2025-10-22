//
//  AddPatientButton.swift
//  HippoVision
//
//  Created by 김현기 on 10/21/25.
//

import SwiftUI

/// 환자 추가 버튼 (Toolbar용)
struct AddPatientButton: View {
    let action: () async -> Void

    var body: some View {
        Button {
            Task {
                await action()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.badge.plus")
                    .font(.title2)

                Text("환자 추가")
                    .font(.title3)
                    .fontWeight(.medium)
            }
            .padding(8)
        }
    }
}

#Preview {
    AddPatientButton {}
}
