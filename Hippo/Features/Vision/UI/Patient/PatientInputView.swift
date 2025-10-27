//
//  PatientInputView.swift
//  HippoVision
//
//  Created by 김현기 on 10/27/25.
//

import SwiftUI

struct PatientInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var appModel
    @State private var viewModel = HomeViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // 상단 헤더
            Section {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonBorderShape(.circle)
                    .glassBackgroundEffect()

                    Spacer()

                    Text("Patient Registration")
                        .font(.title)
                        .foregroundStyle(.primary)

                    Spacer()

                    Button {} label: {}
                        .opacity(0)
                }
            }
            .padding(.top, 36)

            Spacer().frame(height: 56)

            // 입력 폼
            Section(
                header: HStack {
                    Text("환자 번호")
                        .font(.title3)
                    Spacer()
                }
                .padding(.vertical, 12)
            ) {
                TextField("환자번호를 입력해주세요", text: $viewModel.patientNumber)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(.thickMaterial)
                    .cornerRadius(12)
            }

            Spacer().frame(height: 28)

            Section(
                header: HStack {
                    Text("이름")
                        .font(.title3)
                    Spacer()
                }
                .padding(.vertical, 12)
            ) {
                TextField("이름을 입력해주세요", text: $viewModel.name)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(.thickMaterial)
                    .cornerRadius(12)
            }

            Spacer().frame(height: 28)

            Section(
                header: HStack {
                    Text("출생연도")
                        .font(.title3)
                    Spacer()
                }
                .padding(.vertical, 12)
            ) {
                HStack {
                    DatePicker(
                        "",
                        selection: $viewModel.birthDate,
                        displayedComponents: .date
                    )
                    .labelsHidden()

                    Spacer()
                }
            }

            Spacer().frame(height: 28)

            Section(
                header: HStack {
                    Text("성별")
                        .font(.title3)
                    Spacer()
                }
                .padding(.vertical, 12)
            ) {
                HStack {
                    Picker("", selection: $viewModel.selectedGender) {
                        ForEach(Gender.allCases) { gender in
                            Text(gender.rawValue.capitalized).tag(gender)
                        }
                    }
                    .pickerStyle(.palette)
                    .frame(width: 200)

                    Spacer()
                }
            }

            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(width: 512, height: 700)
        .glassBackgroundEffect(displayMode: .always)
        .ornament(attachmentAnchor: .scene(.bottom)) {
            OrnamentButton {
                Task {
                    await viewModel.create(
                        patientNumber: viewModel.patientNumber,
                        name: viewModel.name,
                        gender: viewModel.selectedGender,
                        birthDate: viewModel.birthDate
                    )
                    appModel.patients += 1
                    dismiss()
                }
            }
            .systemName("square.and.arrow.down")
            .content("추가하기")
        }
    }
}

#Preview {
    PatientInputView()
}
