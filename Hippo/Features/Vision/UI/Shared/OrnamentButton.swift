//
//  AddPatientButton.swift
//  HippoVision
//
//  Created by 김현기 on 10/21/25.
//

import SwiftUI

/// 환자 추가 버튼 (Toolbar용)
struct OrnamentButton: View {
    let action: () async -> Void

    var systemName: String = "person.badge.plus"
    var content: String = "환자 추가"

    var body: some View {
        Button {
            Task {
                await action()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemName)
                    .font(.title2)

                Text(content)
                    .font(.title3)
                    .fontWeight(.medium)
            }
            .padding(16)
        }
        .glassBackgroundEffect()
    }
}

extension OrnamentButton {
    func systemName(_ systemName: String) -> Self {
        var view = self
        view.systemName = systemName

        return view
    }

    func content(_ content: String) -> Self {
        var view = self
        view.content = content

        return view
    }
}

#Preview {
    OrnamentButton {}
}
