//
//  HomeViewMockData.swift
//  Hippo
//
//  Created by Hyeok Cho on 11/3/25.
//

import Foundation

// MARK: - Patient Display Model

/// View 레이어 전용 Patient 모델
public struct HomeMockDataModel: Identifiable, Equatable, Sendable {
    public let id: String
    public let patientNumber: String
    public let name: String
    public let gender: String
    public let age: String
}

extension HomeMockDataModel {
    /// 샘플 환자 목데이터 리스트
    public static let mockList: [HomeMockDataModel] = [
        HomeMockDataModel(id: "1", patientNumber: "P20231101", name: "김철수", gender: "남", age: "34"),
        HomeMockDataModel(id: "2", patientNumber: "P20231102", name: "이영희", gender: "여", age: "28"),
        HomeMockDataModel(id: "3", patientNumber: "P20231103", name: "박민준", gender: "남", age: "42"),
        HomeMockDataModel(id: "4", patientNumber: "P20231104", name: "최수민", gender: "여", age: "52"),
        HomeMockDataModel(id: "5", patientNumber: "P20231105", name: "오세훈", gender: "남", age: "63")
    ]
}
