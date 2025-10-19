//
//  PatientListView.swift
//  HippoVision
//
//  Created by 김현기 on 10/18/25.
//

import SwiftUI

struct PatientListView: View {
    @State private var patients: [String] = []

    var body: some View {
        VStack(alignment: .leading) {
            Text("환자 리스트")
                .foregroundStyle(.primary)
                .font(.extraLargeTitle2)
                .padding(.horizontal, 40)
                .padding(.top, 40)

            Divider().padding(.vertical)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        PatientGrid(patients: patients) {
            // TODO: 실제 추가 로직 연결(시트/네비게이션 등)
            patients.append("홍길동 \(patients.count + 1)")
        }
        .padding(.horizontal, 40)
    }
}

// 환자 추가 타일(시스템 컴포넌트 위주)
struct AddPatientTile: View {
    var action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "plus")
                .foregroundStyle(.quaternary)
                .font(.system(size: 64, weight: .bold))

            Text("환자 추가")
                .foregroundStyle(.quaternary)
                .font(.title)
        }
        .frame(width: 280, height: 200)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .glassBackgroundEffect(in: .rect(cornerRadius: 20))
        .onTapGesture { action() }
    }
}

// 환자 타일(데모용)
struct PatientTile: View {
    let name: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "person")
                .font(.system(size: 48))
            Text(name)
                .font(.headline)
                .lineLimit(1)
        }
        .frame(width: 280, height: 200)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .glassBackgroundEffect(in: .rect(cornerRadius: 20))
        .hoverEffect(.lift)
    }
}

// 그리드 컨테이너
struct PatientGrid: View {
    let patients: [String]
    var onTapAdd: () -> Void

    var columns: [GridItem] = [
        GridItem(.adaptive(minimum: 280), spacing: 24, alignment: .top),
    ]

    var body: some View {
        VStack {
            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
                    AddPatientTile(action: onTapAdd)
                    ForEach(patients, id: \.self) { name in
                        PatientTile(name: name)
                    }
                }
                .padding(.vertical, 24)
            }
            .scrollIndicators(.hidden)
        }
    }
}

#Preview {
    PatientListView()
}
