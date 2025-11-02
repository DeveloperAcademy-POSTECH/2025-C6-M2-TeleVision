//
//  DetailHeader.swift
//  HippoVision
//
//  Created by 김현기 on 10/21/25.
//

import SwiftUI

struct DetailHeader: View {
    let operation: OperationDisplayModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(operation.status.displayText)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.red)

                Text(operation.title)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
    }
}

#Preview {
    DetailHeader(operation: OperationDisplayModel.MockData)
}
