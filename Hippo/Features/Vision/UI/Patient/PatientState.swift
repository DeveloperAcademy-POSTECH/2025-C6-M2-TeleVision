//
//  PatientState.swift
//  Hippo
//
//  Created by 김현기 on 11/5/25.
//

import Foundation
import Observation

/// State for Patient list view
@MainActor
@Observable
public final class PatientState {
    public enum LoadingError: LocalizedError {
        case fetchFailed(Error)
        case deleteFailed(Error)

        public var errorDescription: String? {
            switch self {
            case let .fetchFailed(error):
                return "환자 정보를 불러오는데 실패했습니다: \(error.localizedDescription)"
            case let .deleteFailed(error):
                return "환자 삭제에 실패했습니다: \(error.localizedDescription)"
            }
        }
    }

    public var patient: PatientDisplayModel?
    public var isLoading: Bool
    public var error: LoadingError?

    public var alertMessage: String? {
        error?.errorDescription
    }

    public init(
        patient: PatientDisplayModel? = nil,
        isLoading: Bool = false,
        error: LoadingError? = nil
    ) {
        self.patient = patient
        self.isLoading = isLoading
        self.error = error
    }
}
