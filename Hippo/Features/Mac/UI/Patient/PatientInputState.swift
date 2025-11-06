//
//  PatientInputState.swift
//  HippoMac
//
//  Created by Claude on 11/6/25.
//

import Foundation

/// 환자 입력 폼의 상태를 관리하는 구조체
public struct PatientInputState {
    /// 환자 등록 번호
    public var patientNumber: String = ""

    /// 이름
    public var name: String = ""

    /// 성별
    public var selectedGender: Gender = .male

    /// 생년월일
    public var birthDate: Date = Date()

    /// 에러 메시지
    public var errorMessage: String?

    public init() {}

    /// 환자 정보로 초기화 (수정 모드)
    public init(from patient: PatientDisplayModel) {
        self.patientNumber = patient.patientNumber
        self.name = patient.name
        self.selectedGender = patient.gender
        self.birthDate = patient.birthDate
    }

    /// 폼 초기화
    public mutating func reset() {
        patientNumber = ""
        name = ""
        selectedGender = .male
        birthDate = Date()
        errorMessage = nil
    }

    /// 나이 계산
    public var age: Int {
        let calendar = Calendar.current
        let now = Date()
        let yearDiff = calendar.dateComponents([.year], from: birthDate, to: now).year ?? 0
        return max(yearDiff, 0)
    }

    /// 폼 유효성 검증
    public var isValid: Bool {
        !patientNumber.isEmpty && !name.isEmpty
    }
}
