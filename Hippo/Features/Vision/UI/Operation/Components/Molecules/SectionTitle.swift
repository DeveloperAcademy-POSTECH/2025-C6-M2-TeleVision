//
//  SectionTitle.swift
//  HippoVision
//
//  Created by 김현기 on 10/21/25.
//

import SwiftUI

struct SectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(.primary)
    }
}

#Preview {
    SectionTitle(title: "Operations")
}
