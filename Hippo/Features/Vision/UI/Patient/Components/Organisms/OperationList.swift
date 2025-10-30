//
//  OperationList.swift
//  Hippo
//
//  Created by 김현기 on 10/30/25.
//

import SwiftUI

struct OperationList: View {
    let operations: [OperationDisplayModel]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .center) {
                Spacer().frame(height: 40)
                ForEach(operations) { operation in
                    OperationCard(operation: operation)
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

#Preview {
    OperationList(operations: [
        OperationDisplayModel.MockData,
        OperationDisplayModel.MockData,
    ])
}
