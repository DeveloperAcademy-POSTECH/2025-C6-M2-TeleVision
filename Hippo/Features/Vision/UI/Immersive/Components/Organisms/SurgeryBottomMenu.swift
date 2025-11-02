//
//  SurgeryBottomMenu.swift
//  Hippo
//
//  Created by 김현기 on 10/27/25.
//

import SwiftUI

struct SurgeryBottomMenu: View {
    let patient: PatientDisplayModel
    @Binding var isEndoscopicActive: Bool
    @Binding var isAssetListOpen: Bool
    let isVisible: Bool
    let onOpenEntityPanel: () -> Void
    let onRecord: () -> Void
    let onFinishSurgery: () -> Void

    var body: some View {
        VStack {
            PatientInfoHeader(
                name: patient.name,
                gender: patient.gender,
                ageText: patient.ageText
            )

            Spacer().frame(height: 12)

            SurgeryControlBar(
                isEndoscopicActive: $isEndoscopicActive,
                isAssetListOpen: $isAssetListOpen,
                onOpenEntityPanel: onOpenEntityPanel,
                onRecord: onRecord,
                onFinishSurgery: onFinishSurgery
            )
        }
        .opacity(isVisible ? 1.0 : 0.0)
    }
}

#Preview {
    SurgeryBottomMenu(
        patient: PatientDisplayModel.MockData,
        isEndoscopicActive: .constant(true),
        isAssetListOpen: .constant(true),
        isVisible: true,
        onOpenEntityPanel: {},
        onRecord: {},
        onFinishSurgery: {}
    )
}
