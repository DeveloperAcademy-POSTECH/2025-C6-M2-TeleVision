//
//  PatientInputView.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/4/25.
//

import SwiftUI

struct PatientInputView: View {
    @Binding var isPresentingPatientInput: Bool

    // ViewModel State 바인딩 (HomeView의 rootVM에서 전달받음)
    @Binding var state: PatientInputState
    let mode: PatientInputMode
    let onSave: () async -> Void

    var body: some View {
        Section(header: Text("환자 추가하기")) {
            Form {
                TextField("환자등록번호", text: $state.patientNumber)
                TextField("이름", text: $state.name)
                Picker("성별", selection: $state.selectedGender) {
                    Text("남성").tag(Gender.male)
                    Text("여성").tag(Gender.female)
                }
                .pickerStyle(.segmented)
                HStack {
                    DatePicker(
                        "출생날짜",
                        selection: $state.birthDate,
                        displayedComponents: [.date]
                    )
                    .environment(\.locale, Locale(identifier: "ko_KR"))
                    Text("\(state.age)세")
                }
            }
        }
        .padding()
        
        Divider()
            .padding(.horizontal)
        
        HStack {
            Button("취소") {
                isPresentingPatientInput = false
            }
            Button("저장") {
                //TODO: 수술 저장 기능 구현
                if state.isValid {
                    Task {
                        await onSave()
                    }
                }
                isPresentingPatientInput = false
            }
        }
        .padding()

    }
}

#Preview {
    RootView()
}
