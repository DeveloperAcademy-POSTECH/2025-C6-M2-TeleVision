//
//  SectionHeader.swift
//  HippoVision
//
//  Created by 김현기 on 10/21/25.
//

import SwiftUI

/// 재사용 가능한 섹션 헤더
struct SectionHeader: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.tertiary)
                .font(.largeTitle)

            Spacer()

            if let subtitle = subtitle {
                Text(subtitle)
                    .foregroundStyle(.quaternary)
                    .font(.title)
            }
        }
    }
}

#Preview {
    SectionHeader("Patients List")
}
