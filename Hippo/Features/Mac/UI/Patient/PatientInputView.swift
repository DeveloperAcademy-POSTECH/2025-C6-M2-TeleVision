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
        VStack {
            Section {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing:  16) {
                    GridRow {
                        Text("Patient Number")
                        TextField("", text: $state.patientNumber)
                    }
                    GridRow {
                        Text("Name")
                        TextField("", text: $state.name)
                    }
                    GridRow {
                        Text("Gender")
                        Picker("", selection: $state.selectedGender) {
                            Text("Male").tag(Gender.male)
                            Text("Female").tag(Gender.female)
                        }
                        .pickerStyle(.segmented)
                        .tint(.hippoPrimary)
                    }
                    GridRow {
                        Text("Birth Date")
                        HStack {
                            DatePicker(
                                "",
                                selection: $state.birthDate,
                                displayedComponents: [.date]
                            )
                            .environment(\.locale, Locale(identifier: "ko_KR"))
                            Text("Age \(state.age)")
                                .font(.footnote)
                                .fontWeight(.medium)
                                .foregroundColor(.hippoGray500)
                        }
                    }
                }
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundColor(.hippoGray900)
                .padding()
            } header: {
                Text("Add Patient")
                    .font(.headline)
                    .foregroundColor(.hippoGray500)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            FormActionBar(
                isPresenting: $isPresentingPatientInput,
                canSave: state.isValid,
                onSave: onSave
            )
        }
        .padding()
    }
}

#Preview {
    RootView()
}

