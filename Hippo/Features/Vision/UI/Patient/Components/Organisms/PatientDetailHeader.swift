//
//  PatientDetailHeader.swift
//  Hippo
//
//  Created by 김현기 on 10/30/25.
//

import SwiftUI

struct PatientDetailHeader: View {
    @Environment(AppModel.self) private var appModel
    @Environment(PatientViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    let name: String
    let gender: String
    let ageText: String
    let number: String
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
            }
            .buttonBorderShape(.circle)
            .glassBackgroundEffect()

            Spacer()

            HStack {
                Text(name)
                    .font(.title)
                    .foregroundStyle(.primary)

                Spacer().frame(width: 8)

                Text("\(gender) / \(ageText)")
                    .foregroundStyle(.tertiary)

                Spacer().frame(width: 4)

                Text("(\(number))")
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Menu {
                Button("환자 편집") {
                    viewModel.isShowingEditSheet = true
                }
                Button("환자 삭제", role: .destructive) {
                    Task {
                        await viewModel.deleteCurrentPatient()
                        dismiss()
                        appModel.patients -= 1
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
        name: "김환자",
        gender: "남",
        ageText: "45세",
        number: "",
        onDismiss: {}
    )
}
