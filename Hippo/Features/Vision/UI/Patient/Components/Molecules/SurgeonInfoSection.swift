//
//  SurgeonInfoSection.swift
//  Hippo
//
//  Created by 김현기 on 10/30/25.
//

import SwiftUI

struct SurgeonInfoSection: View {
    let surgeonName: String

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("집도의")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
                Text(surgeonName)
                    .font(.title)
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 28)
    }
}

#Preview {
    SurgeonInfoSection(surgeonName: "김외과")
}
