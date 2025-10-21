//
//  OperationDateBadge.swift
//  HippoVision
//
//  Created by 김현기 on 10/21/25.
//

import SwiftUI

/// 수술 D-Day 배지
struct OperationDateBadge: View {
    let date: Date

    private var daysUntilOperation: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let operationDay = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: today, to: operationDay)
        return components.day ?? 0
    }

    private var badgeText: String {
        switch daysUntilOperation {
        case 0: return "Today"
        case 1...: return "D-\(daysUntilOperation)"
        default: return "D+\(abs(daysUntilOperation))"
        }
    }

    var body: some View {
        Text(badgeText)
            .font(.callout)
            .foregroundStyle(.primary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.regularMaterial)
            )
    }
}

#Preview {
    OperationDateBadge(date: Date())
}
