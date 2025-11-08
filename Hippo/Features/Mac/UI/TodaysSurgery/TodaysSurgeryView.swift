//
//  TodaysSurgeryView.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/3/25.
//

import SwiftUI

struct TodaysSurgeryView: View {
    // TodaysSurgeryViewModel 사용
    let viewModel: TodaysSurgeryViewModel

    var body: some View {

        let operations = viewModel.operationCards

        return OperationListView(
            operations: operations,
            onEdit: { operationID in
                if let op = operations.first(where: { $0.id == operationID }) {
                    let patientId = op.patientId
                    Task {
                        
                    }
                }
            },
            onDelete: { operationID in
                if let op = operations.first(where: { $0.id == operationID }) {
                    let patientId = op.patientId
                    Task {
                        await viewModel.deleteOperationCard(operationID, in: patientId)
                    }
                }
            }
        )
    }

}

#Preview {
    let rootVM = MacRootViewModel()
    TodaysSurgeryView(viewModel: TodaysSurgeryViewModel(rootVM: rootVM))
}
