//
//  OperationListViewDataModel.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/7/25.
//

import Foundation

///OperationCardView용 데이터 모델
public struct OperationCardDisplayModel: Equatable, Identifiable, Sendable {
    public let id: String
    public let patientId: String
    public let name: String?
    public let gender: String?
    public let birthDate: Date?
    public let title: String
    public let diagnosis: String
    public let surgeon: String
    public let surgicalSite: String
    public let operationDate: Date
    public let details: String
    public let assets: [OperationAssetDisplayModel]

    public var age: String {
        String(
            max(
                Calendar.current.dateComponents(
                    [.year],
                    from: birthDate ?? Date(),
                    to: Date()
                ).year ?? 0,
                0
            )
        )
    }

    public init(
        id: String,
        patientId: String,
        name: String? = nil,
        gender: String? = nil,
        birthDate: Date? = nil,
        title: String,
        diagnosis: String,
        surgeon: String,
        surgicalSite: String,
        operationDate: Date,
        details: String,
        assets: [OperationAssetDisplayModel]
    ) {
        self.id = id
        self.patientId = patientId
        self.name = name
        self.gender = gender
        self.birthDate = birthDate
        self.title = title
        self.diagnosis = diagnosis
        self.surgeon = surgeon
        self.surgicalSite = surgicalSite
        self.operationDate = operationDate
        self.details = details
        self.assets = assets
    }
}
