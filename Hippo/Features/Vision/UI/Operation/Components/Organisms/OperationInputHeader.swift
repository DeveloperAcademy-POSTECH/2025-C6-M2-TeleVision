//
//  OperationInputHeader.swift
//  Hippo
//
//  Created by 김현기 on 10/30/25.
//

import SwiftUI

struct OperationInputHeader: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
            }
            .buttonBorderShape(.circle)
            .glassBackgroundEffect()

            Spacer()

            Text("Surgery Registration")
                .font(.title)
                .foregroundStyle(.primary)

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.top, 36)
    }
}
