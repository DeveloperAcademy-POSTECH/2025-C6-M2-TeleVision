import SwiftUI

struct PatientSelectButton: View {
    @Binding var rootVM: MacRootViewModel
    let data: PatientDisplayModel

    var body: some View {
        HStack {
            Button {
                rootVM.selectPatient(data.id)
            } label: {
                HStack(spacing: 12) {
                    Text(data.patientNumber)
                    Text(data.name)
                    Text(data.genderText)
                    Text("Age \(data.age)")
                    Spacer()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .font(.body)
                .foregroundColor(rootVM.navigationState.selectedPatientID == data.id ? .white : .hippoGray)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(rootVM.navigationState.selectedPatientID == data.id ? .hippoPrimary : .white)
                )
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button {
                    rootVM.openPatientEditSheet(patient: data)
                } label: {
                    Text("Edit")
                        .padding(.horizontal, 8)
                }
                Button(role: .destructive) {
                    Task { await rootVM.deletePatient(data.id) }
                } label: {
                    Text("Delete")
                        .padding(.horizontal, 8)
                }
            }
        }
    }
}
