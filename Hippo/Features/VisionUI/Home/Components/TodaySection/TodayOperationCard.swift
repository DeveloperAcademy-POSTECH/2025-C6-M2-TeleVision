//
//  TodayOperationCard.swift
//  HippoVision
//
//  Created by 김현기 on 10/20/25.
//

import SwiftUI

struct TodayOperationCard: View {
    let patient: PatientDisplayModel

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    private var operation: OperationDisplayModel {
        guard let op = patient.lastestOperation else {
            fatalError("No latest operation found for patient \(patient.name)")
        }
        return op
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 헤더: 수술명 + 상태 배지
            VStack {
                HStack {
                    Text(operation.date, formatter: timeFormatter)
                        .font(.extraLargeTitle2)
                        .foregroundStyle(.primary)

                    Spacer()

                    // 수술 상태 배지 (수술 대기 / 수술 완료)
                    Text(operation.status)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color(operation.statusColor))
                        )
                }

                Text(operation.title)
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            Divider()
                .padding(.vertical, 12)

            Spacer()

            // 환자 정보 그리드 (2x2)
            VStack(spacing: 20) {
                // 첫 번째 행
                HStack(spacing: 0) {
                    // 환자 정보
                    VStack(alignment: .leading, spacing: 6) {
                        Text("환자 정보")
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        HStack {
                            Text("\(patient.name)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)

                            Text("(\(patient.gender) / \(patient.age)세)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // 집도의
                    VStack(alignment: .leading, spacing: 6) {
                        Text("집도의")
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        Text(operation.surgeon)
                            .font(.title3)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // 두 번째 행
                HStack(spacing: 0) {
                    // 수술부위
                    VStack(alignment: .leading, spacing: 6) {
                        Text("수술부위")
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        Text(operation.diagnosis)
                            .font(.title3)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // 진단(병명)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("진단(병명)")
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        Text(operation.diagnosis)
                            .font(.title3)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(width: 430)
        .background(
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(.quaternary)
        )
        .hoverEffect(.lift)
    }
}

#Preview {
    TodayOperationCard(patient: PatientDisplayModel.sample)
}
