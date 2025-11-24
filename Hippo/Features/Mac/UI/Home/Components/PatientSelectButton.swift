import SwiftUI

struct PatientSelectButton: View {
    @Binding var rootVM: MacRootViewModel
    let data: PatientDisplayModel

    var body: some View {
        HStack {
            Button {
                rootVM.selectPatient(data.id)
            } label: {
                HStack(alignment: .center) {
                    Spacer()
                    Text(data.patientNumber)
                    Spacer()
                    Text(data.name)
                    Spacer()
                    Text(data.genderText)
                    Spacer()
                    Text("\(data.age)세")
                    Spacer()
                    Menu {
                        Button {
                            rootVM.openPatientEditSheet(patient: data)
                        } label: {
                            HStack {
                                Image(systemName: "pencil")
                                    .padding(.trailing, 4)
                                Text("편집")
                            }
                        }
                        Button(role: .destructive) {
                            Task { await rootVM.deletePatient(data.id) }
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                    .padding(.trailing, 4)
                                Text("삭제")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .foregroundStyle(.hippoGray200)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
                .font(.body)
                .foregroundColor(rootVM.navigationState.selectedPatientID == data.id ? .white : .hippoGray700)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(rootVM.navigationState.selectedPatientID == data.id ? .hippoPrimary : .white)
                )
            }
            .buttonStyle(.plain)
        }
    }
}
