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
            OperationStatusBadge(status: operation.status)

            Spacer()

            HStack(spacing: 16) {
                Button {} label: {
                    Image(systemName: "video")
                        .foregroundStyle(.primary)
                }
                .frame(width: 44, height: 44)
                .contentShape(.circle)
                .glassBackgroundEffect()
                .help(operation.assets.isEmpty ? "No Video" : "Video")

                Button {} label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.primary)
                }
                .frame(width: 44, height: 44)
                .contentShape(.circle)
                .glassBackgroundEffect()
                .help("More")
            }
        }

        Divider()
    }
}

#Preview {
    DetailHeader(operation: OperationDisplayModel.MockData)
}
