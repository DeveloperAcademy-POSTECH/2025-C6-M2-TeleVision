//
//  PatientInputForm.swift
//  Hippo
//
//  Created by 김현기 on 10/27/25.
//

import SwiftUI

struct PatientInputForm: View {
    @Binding var patientNumber: String
    @Binding var name: String
    @Binding var birthDate: Date
    @Binding var selectedGender: Gender

    var body: some View {
        VStack(spacing: 28) {
            FormSection {
                TextField("환자번호를 입력해주세요", text: $patientNumber)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(.thinMaterial)
                    .cornerRadius(12)
            }
            .title("환자 번호")

            FormSection {
                TextField("이름을 입력해주세요", text: $name)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(.thinMaterial)
                    .cornerRadius(12)
            }
            .title("이름")

            FormSection {
                HStack {
                    DatePicker(
                        "",
                        selection: $birthDate,
                        displayedComponents: .date
                    )
                    .labelsHidden()

                    Spacer()
                }
            }
            .title("출생연도")

            FormSection {
                HStack {
                    Picker("", selection: $selectedGender) {
                        ForEach(Gender.allCases) { gender in
                            Text(gender.rawValue.capitalized).tag(gender)
                        }
                    }
                    .pickerStyle(.palette)
                    .frame(width: 200)

                    Spacer()
                }
            }
            .title("성별")
        }
    }
}
