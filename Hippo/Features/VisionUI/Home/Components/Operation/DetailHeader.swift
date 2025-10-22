//
//  DetailHeader.swift
//  HippoVision
//
//  Created by 김현기 on 10/21/25.
//

import SwiftUI

struct DetailHeader: View {
    let operation: OperationDisplayModel
    let onClose: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("수술 대기")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.red)

                Text(operation.title)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.primary)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    DetailHeader(operation: OperationDisplayModel.MockData, onClose: {})
}
