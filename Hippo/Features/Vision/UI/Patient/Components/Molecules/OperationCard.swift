//
//  OperationCard.swift
//  Hippo
//
//  Created by 김현기 on 10/30/25.
//

import SwiftUI

struct OperationCard: View {
    let operation: OperationDisplayModel

    let action: () -> Void

    var body: some View {
        VStack {
            OperationInfoSection(operation: operation)

            Divider().padding(.vertical, 12)

            SurgeonInfoSection(surgeonName: operation.surgeon)
        }
        .glassBackgroundEffect()
        .onTapGesture { action() }
        .padding(.bottom, 28)
    }
}

#Preview {
    OperationCard(operation: OperationDisplayModel.MockData) {}
}
