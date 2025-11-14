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
                VStack {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading) {
                            Text("Patient Number")
                            Spacer()
                            
                            Text("Name")
                            Spacer()
                            
                            Text("Gender")
                            Spacer()
                            
                            Text("Birth Date")
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading) {
                            TextField("", text: $state.patientNumber)
                            Spacer()
                            
                            TextField("", text: $state.name)
                            Spacer()
                            
                            Picker("", selection: $state.selectedGender) {
                                Text("Male").tag(Gender.male)
                                Text("Female").tag(Gender.female)
                            }
                            .pickerStyle(.segmented)
                            .tint(.hippoPrimary)
                            Spacer()
                            
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
                    //                        HStack {
                    //                            Text("Patient Number")
                    //                            TextField("", text: $state.patientNumber)
                    //                        }
                    //                        .padding(.vertical, 4)
                    //                        HStack {
                    //                            Text("Patient Number")
                    //                            TextField(" ", text: $state.name)
                    //                        }
                    //                        .padding(.vertical, 4)
                    //                        Picker("Gender", selection: $state.selectedGender) {
                    //                            Text("Male").tag(Gender.male)
                    //                            Text("Female").tag(Gender.female)
                    //                        }
                    //                        .pickerStyle(.segmented)
                    //                        .padding(.vertical, 4)
                    //                        HStack {
                    //                            DatePicker(
                    //                                "Birth Date",
                    //                                selection: $state.birthDate,
                    //                                displayedComponents: [.date]
                    //                            )
                    //                            .environment(\.locale, Locale(identifier: "ko_KR"))
                    //                            Text("Age \(state.age)")
                    //                        }
                }
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundColor(.hippoGray900)
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

