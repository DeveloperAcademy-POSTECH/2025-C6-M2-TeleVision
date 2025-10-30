//
//  PatientDetailHeader.swift
//  Hippo
//
//  Created by 김현기 on 10/30/25.
//

import SwiftUI

struct PatientDetailHeader: View {
    let name: String
    let gender: String
    let ageText: String
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
            }
            .buttonBorderShape(.circle)
            .glassBackgroundEffect()

            Spacer()

            HStack {
                Text(name)
                    .font(.title)
                    .foregroundStyle(.primary)

                Spacer().frame(width: 8)

                Text("\(gender) / \(ageText)")
            }

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.top, 36)
    }
}

#Preview {
    PatientDetailHeader(
        name: "김환자",
        gender: "남",
        ageText: "45세",
        onDismiss: {}
    )
}
