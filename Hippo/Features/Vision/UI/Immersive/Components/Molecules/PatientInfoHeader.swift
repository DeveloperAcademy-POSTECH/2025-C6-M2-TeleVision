//
//  PatientInfoHeader.swift
//  Hippo
//
//  Created by 김현기 on 10/26/25.
//

import SwiftUI

struct PatientInfoHeader: View {
    let name: String
    let gender: String
    let ageText: String

    var body: some View {
        HStack {
            Text(name)
                .font(.extraLargeTitle2)
                .foregroundStyle(.primary)
            Spacer().frame(width: 8)
            Text("\(gender) / \(ageText)")
                .font(.title)
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    PatientInfoHeader(
        name: "김현기",
        gender: "M",
        ageText: "28세"
    )
}
