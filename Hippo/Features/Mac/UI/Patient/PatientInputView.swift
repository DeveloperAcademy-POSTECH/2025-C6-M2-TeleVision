//
//  PatientInputView.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/4/25.
//

import SwiftUI

struct PatientInputView: View {
    @Binding var isPatientInputSheetPresented: Bool
    @State private var birthDate = Date()

    private var age: Int {
        let now = Date()
        let calendar = Calendar.current
        let yearDiff =
            calendar.dateComponents([.year], from: birthDate, to: now).year ?? 0
        return max(yearDiff, 0)
    }

    var body: some View {
        Section(header: Text("환자 추가하기")) {
            Form {
                TextField("환자등록번호", text: .constant(""))
                TextField("이름", text: .constant(""))
                Picker("성별", selection: .constant(0)) {
                    Text("남성")
                    Text("여성")
                }
                .pickerStyle(.segmented)
                HStack {
                    DatePicker(
                        "출생날짜",
                        selection: $birthDate,
                        displayedComponents: [.date]
                    )
                    .environment(\.locale, Locale(identifier: "ko_KR"))
                    Text("\(age)세")
                }
            }
        }
        .padding()

        HStack {
            Button("취소") {
                isPatientInputSheetPresented = false
            }
            Button("저장") {
                isPatientInputSheetPresented = false
            }
        }
        .padding()

    }
}

#Preview {
    RootView()
}
