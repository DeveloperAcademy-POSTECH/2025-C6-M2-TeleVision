//
//  OperationList.swift
//  Hippo
//
//  Created by 김현기 on 10/30/25.
//

import SwiftUI

struct OperationList: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow

    let patientID: String
    let operations: [OperationDisplayModel]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .center) {
                Spacer().frame(height: 40)
                ForEach(operations) { operation in
                    OperationCard(operation: operation) {
                        let context = OperationContext(
                            patientID: patientID,
                            operationID: operation.id
                        )
                        appModel.openOperationDetail(
                            context: context,
                            openWindow: openWindow,
                            dismissWindow: dismissWindow
                        )
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

#Preview {
    OperationList(patientID: "patientID",
                  operations: [
                      OperationDisplayModel.MockData,
                      OperationDisplayModel.MockData,
                  ])
}
