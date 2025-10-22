//
//  DetailSubPart.swift
//  HippoVision
//
//  Created by 김현기 on 10/21/25.
//

import SwiftUI

struct DetailSubPart: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title: title)

            Text(content)
                .font(.system(size: 18))
                .foregroundStyle(.primary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    DetailSubPart(title: "", content: "")
}
