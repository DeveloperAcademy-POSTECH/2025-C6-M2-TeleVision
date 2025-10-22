import SwiftUI

/// macOS-specific Patient list view with Table interface
@MainActor
public struct PatientView: View {
    @State private var viewModel = HomeViewModel()
    @State private var showingAddPatient = false
    @State private var newPatientName = ""
    @State private var newPatientNumber = ""
    @State private var newGender: Gender = .male
    @State private var newBirthDate = Date()
    @State private var selection: Set<String> = []
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
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
                    Table(viewModel.state.items, selection: $selection) {
                        TableColumn("Name") { patient in
                            Text(patient.name)
                                .fontWeight(.medium)
                        }
                        .width(min: 150)

                        TableColumn("Age") { patient in
                            Text(patient.ageText)
                                .foregroundStyle(.secondary)
                        }
                        .width(80)

                        TableColumn("Gender") { patient in
                            Label(
                                patient.gender,
                                systemImage: patient.genderIcon
                            )
                            .foregroundStyle(.secondary)
                        }
                        .width(100)

                        TableColumn("Patient #") { patient in
                            Text(patient.patientNumber)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .width(min: 100)

                        TableColumn("Operations") { patient in
                            Text("\(patient.operationCount)")
                                .foregroundStyle(.blue)
                        }
                        .width(80)

                        TableColumn("Last Updated") { patient in
                            Text(patient.updatedAt, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .width(min: 100)
                    }
                }
            }
            .navigationTitle("Patients")
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        showingAddPatient = true
                    } label: {
                        Label("Add Patient", systemImage: "plus")
                    }

                    Button {
                        Task {
                            guard let patientID = selection.first else {
                                return
                            }
                            await viewModel.remove(patientID: patientID)
                            selection.removeAll()
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(selection.isEmpty)
                }
            }
            .alert(
                "Error",
                isPresented: .constant(viewModel.state.alert != nil)
            ) {
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
                    gender: $newGender,
                    birthDate: $newBirthDate,
                    onAdd: {
                        Task {
                            await viewModel.create(
                                patientNumber: newPatientNumber,
                                name: newPatientName,
                                gender: newGender,
                                birthDate: newBirthDate
                            )
                            newPatientName = ""
                            newPatientNumber = ""
                            newGender = .male
                            newBirthDate = Date()
                            showingAddPatient = false
                        }
                    },
                    onCancel: {
                        newPatientName = ""
                        newPatientNumber = ""
                        newGender = .male
                        newBirthDate = Date()
                        showingAddPatient = false
                    }
                )
            }
            .task {
                await viewModel.load()
                if let firstPatient = viewModel.state.items.first {
                    selection = [firstPatient.id]
                }
            }
            .onChange(of: viewModel.state.items) { oldValue, newValue in
                if selection.isEmpty, let firstPatient = newValue.first {
                    selection = [firstPatient.id]
                }
            }
        } detail: {
            if let patientID = selection.first,
                let patient = viewModel.state.items.first(where: {
                    $0.id == patientID
                })
            {
                PatientDetailView(patient: patient)
            } else {
                ContentUnavailableView(
                    "Select a Patient",
                    systemImage: "person.circle",
                    description: Text(
                        "Select a patient from the list to view details"
                    )
                )
            }
        }
    }
}

// MARK: - Patient Detail View
private struct PatientDetailView: View {
    let patient: PatientDisplayModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Patient Info
                GroupBox("Patient Information") {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(label: "Name", value: patient.name)
                        InfoRow(label: "Gender", value: patient.gender)
                        InfoRow(label: "Age", value: patient.ageText)
                        InfoRow(
                            label: "Patient #",
                            value: patient.patientNumber
                        )
                        InfoRow(
                            label: "Birth Date",
                            value: patient.birthDateText
                        )
                        InfoRow(
                            label: "Last Updated",
                            value: patient.updatedAtText
                        )
                    }
                }

                // Operations
                if !patient.operations.isEmpty {
                    GroupBox("Operations (\(patient.operationCount))") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(patient.operations) { operation in
                                VStack(alignment: .leading, spacing: 4) {

                                    Text(operation.title)
                                        .font(.headline)

                                    Text(operation.diagnosis)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text("Surgeon: \(operation.surgeon)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("Date: \(operation.dateText)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if !operation.assets.isEmpty {
                                        Text("\(operation.assetCount) asset(s)")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .padding(.vertical, 4)
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(patient.name)
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .fontWeight(.medium)
        }
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
        VStack(spacing: 20) {
            Text("New Patient")
                .font(.headline)

            Form {
                TextField("Patient Name", text: $name)
                    .textFieldStyle(.roundedBorder)

                TextField("Patient Number", text: $patientNumber)
                    .textFieldStyle(.roundedBorder)

                Picker("Gender", selection: $gender) {
                    Text("Male").tag(Gender.male)
                    Text("Female").tag(Gender.female)
                }
                .pickerStyle(.segmented)

                DatePicker(
                    "Birth Date",
                    selection: $birthDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add", action: onAdd)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty || patientNumber.isEmpty)
            }
        }
        .padding()
        .frame(width: 450, height: 350)
    }
}

#Preview {
    PatientView()
}
