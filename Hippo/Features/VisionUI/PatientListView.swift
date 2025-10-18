//
//  PatientListView.swift
//  HippoVision
//
//  Created by 김현기 on 10/18/25.
//

import SwiftUI

struct PatientListView: View {
    @State private var patients: [String] = []
    @State private var searchText: String = ""

    private var filteredPatients: [String] {
        guard !searchText.isEmpty else { return patients }
        return patients.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Group {
            if filteredPatients.isEmpty {
                ContentUnavailableView(
                    patients.isEmpty ? "환자 없음" : "검색 결과 없음",
                    systemImage: patients.isEmpty ? "person.2" : "magnifyingglass",
                    description: Text(
                        patients.isEmpty
                            ? "상단 \"+\" 버튼으로 환자를 추가하세요."
                            : "검색어를 변경해 보세요."
                    )
                )
            } else {
                List {
                    Section("환자") {
                        ForEach(filteredPatients, id: \.self) { name in
                            NavigationLink(value: name) {
                                PatientRow(name: name)
                            }
                        }
                    }
                }
                .navigationDestination(for: String.self) { name in
                    PatientDetailPlaceholder(name: name)
                }
            }
        }
    }
}

struct PatientRow: View {
    let name: String

    var body: some View {
        Label(name, systemImage: "person")
            .lineLimit(1)
            .accessibilityLabel("환자 \(name)")
    }
}

struct PatientDetailPlaceholder: View {
    let name: String

    var body: some View {
        Form {
            Section("환자") {
                Text(name)
            }
        }
        .navigationTitle("환자 상세")
    }
}

#Preview {
    PatientListView()
}
