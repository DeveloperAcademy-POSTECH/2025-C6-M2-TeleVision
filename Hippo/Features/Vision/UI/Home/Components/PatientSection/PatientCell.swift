//
//  PatientCell.swift
//  HippoVision
//
//  Created by 김현기 on 10/21/25.
//

import SwiftUI

struct PatientCell: View {
    let patient: PatientDisplayModel
    let action: () -> Void

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

            Text(patient.latestOperation?.diagnosis ?? "예정 수술 없음")
                .font(.body)
                .foregroundStyle(.primary)
                .padding(.horizontal)

            HStack {
                Spacer()

                if let operation = patient.latestOperation {
                    OperationDateBadge(date: operation.date)
                } else {
                    Color.clear.frame(height: 30)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 200, minHeight: 180, maxHeight: 180)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.thinMaterial)
        )
        .hoverEffect(.lift)
        .onTapGesture { action() }
    }
}

#Preview {
    PatientCell(patient: PatientDisplayModel.MockData) {}
}
