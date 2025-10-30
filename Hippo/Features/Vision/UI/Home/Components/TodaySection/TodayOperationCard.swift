//
//  TodayOperationCard.swift
//  HippoVision
//
//  Created by 김현기 on 10/20/25.
//

import SwiftUI

struct TodayOperationCard: View {
    let patient: PatientDisplayModel
    let onTap: () -> Void

    private var operation: OperationDisplayModel {
        guard let op = patient.latestOperation else { return OperationDisplayModel.MockData }
        return op
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 헤더: 수술명 + 상태 배지
            VStack {
                HStack {
                    Text(operation.date.toTimeString())
                        .font(.extraLargeTitle2)
                        .foregroundStyle(.primary)

                    Spacer()

                    // 수술 상태 배지 (수술 대기 / 수술 완료)
                    OperationStatusBadge(
                        status: operation.statusText,
                        color: operation.statusColor
                    )
                }
                
                HStack {
                    Text(operation.title)
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .padding(.top, 4)
                    
                    
                    Spacer()
                }
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
        .background {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(.quaternary)
                .fill(operation.status == .completed ? .hippoBlack : .clear)
        }
        .hoverEffect(.lift)
        .onTapGesture { onTap() }
    }
}

#Preview {
    TodayOperationCard(patient: PatientDisplayModel.MockData) {}
}
