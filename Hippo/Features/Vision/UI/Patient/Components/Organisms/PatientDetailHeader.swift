//
//  PatientDetailHeader.swift
//  Hippo
//
//  Created by 김현기 on 10/30/25.
//

import SwiftUI

struct PatientDetailHeader: View {
    @Environment(AppModel.self) private var appModel
    @Environment(HomeViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
            }
            .buttonBorderShape(.circle)
            .glassBackgroundEffect()

            Spacer()

            if let patient = viewModel.state.selectedPatient {
                HStack {
                    Text(patient.name)
                        .font(.title)
                        .foregroundStyle(.primary)

                    Spacer().frame(width: 8)

                    Text("\(patient.genderText) / \(patient.ageText)")
                        .foregroundStyle(.tertiary)

                    Spacer().frame(width: 4)

                    Text("(\(patient.patientNumber))")
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Menu {
                Button("환자 편집") {
                    viewModel.isShowingEditSheet = true
                }
                Button("환자 삭제", role: .destructive) {
                    Task {
                        await viewModel.deleteCurrentPatient()
                        appModel.refreshUI()
                        dismiss()
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.primary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 44, height: 44)
            .contentShape(.circle)
            .glassBackgroundEffect()
            .help("More")
        }
        .padding(.top, 36)
    }
}

#Preview {
    PatientDetailHeader(
        onDismiss: {}
    )
}
