import Foundation
import Observation

/// State for Patient list view
@MainActor
@Observable
public final class PatientState {
    public var items: [PatientDisplayModel]
    public var selectedPatient: PatientDisplayModel?
    public var isLoading: Bool
    public var alert: String?

    public init(
        items: [PatientDisplayModel] = [],
        selectedPatient: PatientDisplayModel? = nil,
        isLoading: Bool = false,
        alert: String? = nil,
    ) {
        self.items = items
        self.selectedPatient = selectedPatient
        self.isLoading = isLoading
        self.alert = alert
    }
}
