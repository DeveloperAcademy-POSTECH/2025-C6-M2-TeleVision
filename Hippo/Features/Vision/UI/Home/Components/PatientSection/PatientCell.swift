//
//  PatientCell.swift
//  HippoVision
//
//  Created by 김현기 on 10/21/25.
//

import SwiftUI

struct PatientCell: View {
    let patient: PatientDisplayModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(patient.patientNumber)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 12)

            Divider()

            HStack {
                Text(patient.name)
                    .font(.title)
                    .foregroundStyle(.primary)

                Spacer().frame(width: 12)

                Text("\(patient.gender) / \(patient.age)세")
                    .font(.headline)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)

            Text(patient.lastestOperation?.diagnosis ?? "예정 수술 없음")
                .font(.body)
                .foregroundStyle(.primary)
                .padding(.horizontal)

            HStack {
                Spacer()

                if let operation = patient.lastestOperation {
                    OperationDateBadge(date: operation.date)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .frame(minWidth: 200)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.thinMaterial)
        )
        .hoverEffect(.lift)
    }
}

#Preview {
    PatientCell(patient: PatientDisplayModel.sample)
}
