import SwiftUI

/// visionOS-specific Patient list view
@MainActor
public struct PatientView: View {
    @State private var viewModel = PatientViewModel()
    @State private var showingAddPatient = false
    @State private var newPatientName = ""

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
                                            await viewModel.remove(patient)
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
        }
    }
}

// MARK: - Patient Row
private struct PatientRow: View {
    let patient: Patient

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(patient.name)
                .font(.headline)

            HStack(spacing: 16) {
                if let age = patient.age {
                    Label("\(age) years", systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Label(patient.sex.rawValue.capitalized, systemImage: "person")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let mrn = patient.mrn {
                    Label("MRN: \(mrn)", systemImage: "number")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !patient.cases.isEmpty {
                Label("\(patient.cases.count) case(s)", systemImage: "folder")
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
    let onAdd: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Patient Name", text: $name)
                        .textFieldStyle(.roundedBorder)
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
                        .disabled(name.isEmpty)
                }
            }
        }
        .frame(width: 400, height: 300)
        .glassBackgroundEffect()
    }
}

#Preview {
    PatientView()
}
