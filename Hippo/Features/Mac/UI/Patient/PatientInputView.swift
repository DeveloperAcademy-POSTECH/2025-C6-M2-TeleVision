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
        Section(header: Text("Add Patient")) {
            Form {
                TextField("Patient Number", text: $state.patientNumber)
                TextField("name", text: $state.name)
                Picker("gender", selection: $state.selectedGender) {
                    Text("male").tag(Gender.male)
                    Text("female").tag(Gender.female)
                }
                .pickerStyle(.segmented)
                HStack {
                    DatePicker(
                        "Birth Date",
                        selection: $state.birthDate,
                        displayedComponents: [.date]
                    )
                    .environment(\.locale, Locale(identifier: "ko_KR"))
                    Text("Age \(state.age)")
                }
            }
        }
        .padding()
        
        Divider()
            .padding(.horizontal)
        
        HStack {
            Button("Cancel") {
                isPresentingPatientInput = false
            }
            Button("Save") {
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
