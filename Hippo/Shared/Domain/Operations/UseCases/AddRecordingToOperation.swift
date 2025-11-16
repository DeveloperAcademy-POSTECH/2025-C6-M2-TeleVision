//
//  AddRecordingToOperation.swift
//  Hippo
//
//  Created by 김현기 on 11/17/25.
//

import Foundation

/// Use Case for attaching a single asset to an operation
public struct AddRecordingToOperation: Sendable {
    public struct Input: Sendable {
        public let patientID: String
        public let operationID: String
        public let recording: OperationRecording

        public init(patientID: String, operationID: String, recording: OperationRecording) {
            self.patientID = patientID
            self.operationID = operationID
            self.recording = recording
        }
    }

    private let repository: OperationRepository

    public init(repository: OperationRepository) {
        self.repository = repository
    }

    /// Attaches a single asset to an operation
    /// - Parameter input: Input containing patient ID, operation ID, and asset command
    /// - Throws: OperationError.operationNotFound if operation doesn't exist
    /// - Throws: OperationError.patientNotFound if patient doesn't exist
    public func run(_ input: Input) async throws {
        // Add asset through repository
        try await repository.addRecording(
            input.recording,
            toOperationID: input.operationID,
            inPatientID: input.patientID
        )
    }
}
