//
//  PatientButtonView.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/7/25.
//
import SwiftUI

struct PatientButtonView: View {
    let data: PatientDisplayModel
    var onSelect: (PatientDisplayModel) -> Void


    @State private var isHover = false

    var body: some View {
        HStack {
            // 메인 선택 버튼
            Button { onSelect(data) } label: {
                HStack(spacing: 12) {
                    Text(data.patientNumber)
                    Text(data.name)
                    Text(data.genderText)
                    Text("Age: \(data.age)")
                }
            }

            // 호버 시에만 보이는 우측 메뉴
            Menu {
//                Button("Edit")   { onEdit(data.id) }
//                Button("Delete", role: .destructive) { onDelete(data.id) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .opacity(isHover ? 1 : 0)
        }
        .onHover { isHover = $0 }
    }
}
