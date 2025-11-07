//
//  OperationMockDataModel.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/5/25.
//

import Foundation

public struct OperationMockDataModel: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let diagnosis: String
    public let surgeon: String
    public let date: Date
    public let dateText: String
    public let details: String
    public let status: OperationStatus
//    public let assets: [OperationAssetDisplayModel] //아직 명확한 처리 방법 몰라서 주석처리 해 둠
//    public let assetCount: Int ////아직 명확한 처리 방법 몰라서 주석처리 해 둠
}


//목데이터
extension OperationMockDataModel{

    private static let fixedReferenceDate: Date = {
        var components = DateComponents()
        components.year = 2025
        components.month = 11
        components.day = 5
        components.hour = 21
        components.minute = 0
        components.second = 0
        components.timeZone = TimeZone(secondsFromGMT: 9 * 3600) // KST (GMT+9)
        return Calendar(identifier: .gregorian).date(from: components) ?? Date(timeIntervalSince1970: 0)
    }()

    public static let sample = OperationMockDataModel(
        id: "OP-2025-0001",
        title: "우측 무릎 관절경 수술",
        diagnosis: "내측 반월상연골 파열",
        surgeon: "Dr. Kim",
        date: Self.fixedReferenceDate,
        dateText: DateFormatter.localizedString(from: Self.fixedReferenceDate, dateStyle: .medium, timeStyle: .short),
        details: "환자는 우측 무릎 통증을 주소로 내원. 보존적 치료 후에도 통증 지속되어 관절경적 부분 절제술 시행.",
        status: .planned
    )

    public static let patientOperationSamples: [OperationMockDataModel] = [
        OperationMockDataModel(
            id: "OP-2025-0002",
            title: "좌측 어깨 회전근개 봉합술",
            diagnosis: "회전근개 부분 파열",
            surgeon: "Dr. Lee",
            date: {
                var comps = DateComponents()
                comps.day = -2
                comps.hour = 14
                comps.minute = 30
                return Calendar(identifier: .gregorian).date(byAdding: comps, to: Self.fixedReferenceDate)!
            }(),
            dateText: {
                var comps = DateComponents()
                comps.day = -2
                comps.hour = 14
                comps.minute = 30
                let d = Calendar(identifier: .gregorian).date(byAdding: comps, to: Self.fixedReferenceDate)!
                return DateFormatter.localizedString(from: d, dateStyle: .medium, timeStyle: .short)
            }(),
            details: "초음파 및 MRI 상 부분 파열 소견. 관절경하 봉합술 시행.",
            status: .completed
        ),
        OperationMockDataModel(
            id: "OP-2025-0003",
            title: "요추 4-5 추간판 절제술",
            diagnosis: "요추간판 탈출증",
            surgeon: "Dr. Park",
            date: {
                var comps = DateComponents()
                comps.day = 5
                comps.hour = 9
                comps.minute = 15
                return Calendar(identifier: .gregorian).date(byAdding: comps, to: Self.fixedReferenceDate)!
            }(),
            dateText: {
                var comps = DateComponents()
                comps.day = 5
                comps.hour = 9
                comps.minute = 15
                let d = Calendar(identifier: .gregorian).date(byAdding: comps, to: Self.fixedReferenceDate)!
                return DateFormatter.localizedString(from: d, dateStyle: .medium, timeStyle: .short)
            }(),
            details: "좌측 하지 방사통 심화. 보존적 치료 무반응으로 수술 계획.",
            status: .planned
        ),
        OperationMockDataModel(
            id: "OP-2025-0004",
            title: "복강경 담낭절제술",
            diagnosis: "담낭염",
            surgeon: "Dr. Choi",
            date: {
                var comps = DateComponents()
                comps.day = -10
                comps.hour = 18
                comps.minute = 45
                return Calendar(identifier: .gregorian).date(byAdding: comps, to: Self.fixedReferenceDate)!
            }(),
            dateText: {
                var comps = DateComponents()
                comps.day = -10
                comps.hour = 18
                comps.minute = 45
                let d = Calendar(identifier: .gregorian).date(byAdding: comps, to: Self.fixedReferenceDate)!
                return DateFormatter.localizedString(from: d, dateStyle: .medium, timeStyle: .short)
            }(),
            details: "급성 담낭염 진단 하 수술 시행. 합병증 없이 퇴원.",
            status: .completed
        ),
        OperationMockDataModel(
            id: "OP-2025-0005",
            title: "오늘 수술 목업",
            diagnosis: "예시 진단",
            surgeon: "Dr. Han",
            date: {
                Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
            }(),
            dateText: {
                let d = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
                return DateFormatter.localizedString(from: d, dateStyle: .medium, timeStyle: .short)
            }(),
            details: "오늘 날짜에 해당하는 추가 목업 데이터입니다.",
            status: .planned
        )
        ,
        OperationMockDataModel(
            id: "OP-2025-0006",
            title: "오늘 수술 목업 (과거)",
            diagnosis: "예시 진단",
            surgeon: "Dr. Seo",
            date: {
                Calendar.current.date(byAdding: .hour, value: -2, to: Date())!
            }(),
            dateText: {
                let d = Calendar.current.date(byAdding: .hour, value: -2, to: Date())!
                return DateFormatter.localizedString(from: d, dateStyle: .medium, timeStyle: .short)
            }(),
            details: "오늘 날짜에서 2시간 전의 목업 데이터입니다.",
            status: .completed
        )
    ]


    public static func random(id: String = UUID().uuidString, dayOffset: Int = Int.random(in: -14...14)) -> OperationMockDataModel {
        let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date())!
        let titles = ["관절경 수술", "회전근개 봉합", "추간판 절제", "담낭절제", "맹장절제"]
        let diagnoses = ["파열", "염증", "탈출증", "담석증", "충수염"]
        let surgeons = ["Dr. Kim", "Dr. Lee", "Dr. Park", "Dr. Choi", "Dr. Han"]
        let title = titles.randomElement()!
        let diagnosis = diagnoses.randomElement()!
        let surgeon = surgeons.randomElement()!

        return OperationMockDataModel(
            id: id,
            title: title,
            diagnosis: diagnosis,
            surgeon: surgeon,
            date: date,
            dateText: DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short),
            details: "자동 생성된 목업 데이터입니다.",
            status: Bool.random() ? .planned : .completed
        )
    }
}

