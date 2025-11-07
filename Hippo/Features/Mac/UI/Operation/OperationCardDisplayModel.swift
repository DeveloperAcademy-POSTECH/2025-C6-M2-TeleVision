//
//  OperationListViewDataModel.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/7/25.
//

import Foundation

///OperationCardView용 데이터 모델
public struct OperationCardDisplayModel: Equatable, Identifiable {
    
    /// 수술 id
    public var id: String = ""
    
    /// 환자 id
    public var patientId: String = ""
    
    /// 이름
    public var name: String? = nil

    /// 성별
    public var gender: String? = nil
    
    /// 생년월일
    public var birthDate: Date? = nil
    
    /// 수술 제목
    public var title: String = ""

    /// 진단(병명)
    public var diagnosis: String = ""

    /// 집도의
    public var surgeon: String = ""

    /// 수술 부위
    public var surgicalSite: String = ""

    /// 수술 날짜
    public var operationDate: Date = Date()

    /// 수술 상세
    public var details: String = ""

    /// 3D 모델 에셋 목록
    public var assets: [OperationAssetDisplayModel] = []

    
    /// 나이(문자열)
    public var age: String {
        String(max(Calendar.current.dateComponents([.year], from: birthDate ?? Date(), to: Date()).year ?? 0, 0))
    }
}
