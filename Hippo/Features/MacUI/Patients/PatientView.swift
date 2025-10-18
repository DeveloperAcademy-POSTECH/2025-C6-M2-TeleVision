import SwiftUI

/// macOS-specific Patient list view with Table interface
@MainActor
public struct PatientView: View {
    @State private var viewModel = PatientViewModel()
    @State private var showingAddPatient = false
    @State private var newPatientName = ""
    @State private var selection: Set<PatientID> = []

    public init() {}

    public var body: some View {
        NavigationSplitView {
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
                            if let age = patient.age {
                                Text("\(age) years")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("—")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .width(80)

                        TableColumn("Sex") { patient in
                            Text(patient.sex.rawValue.capitalized)
                                .foregroundStyle(.secondary)
                        }
                        .width(80)

                        TableColumn("MRN") { patient in
                            if let mrn = patient.mrn {
                                Text(mrn)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("—")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .width(min: 100)

                        TableColumn("Operations") { patient in
                            Text("\(patient.operations.count)")
                                .foregroundStyle(.blue)
                        }
                        .width(60)

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
                            guard let patientID = selection.first,
                                  let patient = viewModel.state.items.first(where: { $0.id == patientID })
                            else { return }

                            await viewModel.remove(patient)
                            selection.removeAll()
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(selection.isEmpty)
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
                    onAdd: {
                        Task {
                            await viewModel.create(name: newPatientName)
                            newPatientName = ""
                            showingAddPatient = false
                        }
                    },
                    onCancel: {
                        newPatientName = ""
                        showingAddPatient = false
                    }
                )
            }
            .task {
                await viewModel.load()
            }
        } detail: {
            if let patientID = selection.first,
               let patient = viewModel.state.items.first(where: { $0.id == patientID }) {
                PatientDetailView(patient: patient)
            } else {
                ContentUnavailableView(
                    "Select a Patient",
                    systemImage: "person.circle",
                    description: Text("Select a patient from the list to view details")
                )
            }
        }
    }
}

// MARK: - Patient Detail View
private struct PatientDetailView: View {
    let patient: Patient

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Patient Info
                GroupBox("Patient Information") {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(label: "Name", value: patient.name)
                        InfoRow(label: "Sex", value: patient.sex.rawValue.capitalized)
                        if let age = patient.age {
                            InfoRow(label: "Age", value: "\(age) years")
                        }
                        if let mrn = patient.mrn {
                            InfoRow(label: "MRN", value: mrn)
                        }
                        InfoRow(label: "Last Updated", value: patient.updatedAt.formatted())
                    }
                }

                // Operations
                if !patient.operations.isEmpty {
                    GroupBox("Operations (\(patient.operations.count))") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(patient.operations) { operationItem in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(operationItem.title)
                                        .font(.headline)
                                    Text(operationItem.diagnosis)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    if !operationItem.operationAssets.isEmpty {
                                        Text("\(operationItem.operationAssets.count) asset(s)")
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
                .frame(width: 100, alignment: .leading)
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Add Patient Sheet
private struct AddPatientSheet: View {
    @Binding var name: String
    let onAdd: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("New Patient")
                .font(.headline)

            Form {
                TextField("Patient Name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add", action: onAdd)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 200)
    }
}

#Preview {
    PatientView()
}
