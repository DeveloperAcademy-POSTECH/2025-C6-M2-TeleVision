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
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 24, verticalSpacing:  16) {
                    GridRow {
                        Text("환자번호")
                        TextField("", text: $state.patientNumber)
                    }
                    GridRow {
                        Text("이름")
                        TextField("", text: $state.name)
                    }
                    GridRow {
                        Text("성별")
                        Picker("", selection: $state.selectedGender) {
                            Text("Male").tag(Gender.male)
                            Text("Female").tag(Gender.female)
                        }
                        .pickerStyle(.segmented)
                        .tint(.hippoPrimary)
                    }
                    GridRow {
                        Text("생년월일")
                        HStack {
                            DatePicker(
                                "",
                                selection: $state.birthDate,
                                displayedComponents: [.date]
                            )
                            .environment(\.locale, Locale(identifier: "ko_KR"))
                            Text("\(state.age)세")
                                .font(.footnote)
                                .fontWeight(.medium)
                                .foregroundColor(.hippoGray500)
                        }
                    }
                }
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundColor(.hippoGray900)
            } header: {
                Text("환자 추가")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.hippoGray500)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 8)
            }
            .padding(.bottom)

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

