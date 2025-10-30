//
//  OperationInfoSection.swift
//  Hippo
//
//  Created by 김현기 on 10/30/25.
//

import SwiftUI

struct OperationInfoSection: View {
    let operation: OperationDisplayModel

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                OperationStatusBadge(
                    status: operation.statusText,
                    color: operation.statusColor
                )
                Spacer()
            }
            .padding(.bottom)

            Text(operation.title)
                .font(.largeTitle)
                .foregroundStyle(.primary)
                .padding(.bottom, 8)

            Text(operation.date.toOperationDateString())
                .font(.title2)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
    }
}

#Preview {
    OperationInfoSection(operation: OperationDisplayModel.MockData)
}
