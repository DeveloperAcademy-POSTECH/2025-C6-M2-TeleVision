//
//  PatientDetailView.swift
//  HippoVision
//
//  Created by 김현기 on 10/27/25.
//

import SwiftUI

struct PatientDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = PatientViewModel()

    let patientId: String

    private var patient: PatientDisplayModel {
        viewModel.patient ?? PatientDisplayModel.MockData
    }

    var body: some View {
        VStack {
            PatientDetailHeader(
                name: patient.name,
                gender: patient.gender,
                ageText: patient.ageText,
                onDismiss: { dismiss() }
            )

            Spacer()

            if patient.operationCount != 0 {
                OperationList(operations: patient.operations)
            } else {
                EmptyOperationView()
            }

            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(minWidth: 512, maxWidth: 512, minHeight: 620, maxHeight: 1020)
        .glassBackgroundEffect(displayMode: .always)
        .task {
            await viewModel.load(patientID: patientId)
        }
        .ornament(attachmentAnchor: .scene(.bottom)) {
            OrnamentButton {}
                .systemName("long.text.page.and.pencil")
                .content("수술 추가")
        }
    }
}

#Preview {
    PatientDetailView(patientId: "sample-001")
}
