//
//  Date+Extension.swift
//  HippoVision
//
//  Created by 김현기 on 10/21/25.
//

import SwiftUI

extension Date {
    /// yyyy.MM.dd [HH:mm] 형식으로 변환
    func toOperationDateString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy.MM.dd [HH:mm]"
        return formatter.string(from: self)
    }

    /// yyyy.MM.dd 형식으로 변환
    func toTodayDateString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: self)
    }

    /// HH:mm 형식으로 변환
    func toTimeString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }

    /// yyyy.MM.dd 형식의 문자열을 Date로 변환
    static func fromTodayDateString(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.date(from: dateString)
    }
}
