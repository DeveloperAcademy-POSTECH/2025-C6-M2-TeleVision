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
                .font(.system(size: 10))
                .foregroundStyle(.primary)
            Spacer().frame(width: 4)
            Text("\(gender) / \(ageText)")
                .font(.system(size: 8))
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
