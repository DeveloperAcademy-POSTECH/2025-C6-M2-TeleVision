import SwiftUI

/// visionOS-specific Patient list view
@MainActor
public struct PatientView: View {
    @State private var viewModel = HomeViewModel()
    @State private var showingAddPatient = false
    @State private var newPatientName = ""
    @State private var newPatientNumber = ""
    @State private var newPatientGender: Gender = .male
    @State private var newPatientBirthDate = Date()

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.state.isLoading {
                    ProgressView("Loading patients...")
                } else if viewModel.state.items.isEmpty {
                    ContentUnavailableView(
                        "No Patients",
                        systemImage: "person.2.slash",
                        description: Text("Add a patient to get started")
                    )
                } else {
                    List {
                        ForEach(viewModel.state.items) { patient in
                            PatientRow(patient: patient)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task {
                                            await viewModel.remove(patientID: patient.id)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("Patients")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddPatient = true
                    } label: {
                        Label("Add Patient", systemImage: "plus")
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.state.alert != nil)) {
                Button("OK") {
                    viewModel.dismissAlert()
                }
            } message: {
                if let alert = viewModel.state.alert {
                    Text(alert)
                }
            }
            .sheet(isPresented: $showingAddPatient) {
                AddPatientSheet(
                    name: $newPatientName,
                    patientNumber: $newPatientNumber,
                    gender: $newPatientGender,
                    birthDate: $newPatientBirthDate,
                    onAdd: {
                        Task {
                            await viewModel.create(
                                patientNumber: newPatientNumber,
                                name: newPatientName,
                                gender: newPatientGender,
                                birthDate: newPatientBirthDate
                            )
                            newPatientName = ""
                            newPatientNumber = ""
                            newPatientGender = .male
                            newPatientBirthDate = Date()
                            showingAddPatient = false
                        }
                    },
                    onCancel: {
                        newPatientName = ""
                        newPatientNumber = ""
                        newPatientGender = .male
                        newPatientBirthDate = Date()
                        showingAddPatient = false
                    }
                )
            }
            .task {
                await viewModel.load()
            }
        }
    }
}

// MARK: - Patient Row
private struct PatientRow: View {
    let patient: PatientDisplayModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(patient.name)
                .font(.headline)

            HStack(spacing: 16) {
                Label("\(patient.age) years", systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label(patient.gender.capitalized, systemImage: patient.genderIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label("No. \(patient.patientNumber)", systemImage: "number")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if patient.operationCount > 0 {
                Label("\(patient.operationCount) operation(s)", systemImage: "folder")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Patient Sheet
private struct AddPatientSheet: View {
    @Binding var name: String
    @Binding var patientNumber: String
    @Binding var gender: Gender
    @Binding var birthDate: Date
    let onAdd: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Patient Information") {
                    TextField("Patient Number", text: $patientNumber)
                        .textFieldStyle(.roundedBorder)

                    TextField("Patient Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                Section("Demographics") {
                    Picker("Gender", selection: $gender) {
                        Text("Male").tag(Gender.male)
                        Text("Female").tag(Gender.female)
                    }
                    .pickerStyle(.segmented)

                    DatePicker(
                        "Birth Date",
                        selection: $birthDate,
                        displayedComponents: [.date]
                    )
                }
            }
            .navigationTitle("New Patient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: onAdd)
                        .disabled(name.isEmpty || patientNumber.isEmpty)
                }
            }
        }
        .frame(width: 500, height: 400)
        .glassBackgroundEffect()
    }
}

#Preview {
    PatientView()
}
