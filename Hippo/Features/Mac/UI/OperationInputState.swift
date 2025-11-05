//
//  OperationInputState.swift
//  HippoMac
//
//  Created by Claude on 11/6/25.
//

import Foundation

/// 수술 입력 폼의 상태를 관리하는 구조체
public struct OperationInputState {
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

    /// 파일 피커 표시 여부
    public var isShowingFilePicker: Bool = false

    /// 에러 메시지
    public var errorMessage: String?

    public init() {}

    /// 수술 정보로 초기화 (수정 모드)
    public init(from operation: OperationDisplayModel) {
        self.title = operation.title
        self.diagnosis = operation.diagnosis
        self.surgeon = operation.surgeon
        self.surgicalSite = operation.surgicalSite
        self.operationDate = operation.date
        self.details = operation.details
        self.assets = operation.assets
    }

    /// 폼 초기화
    public mutating func reset() {
        title = ""
        diagnosis = ""
        surgeon = ""
        surgicalSite = ""
        operationDate = Date()
        details = ""
        assets = []
        isShowingFilePicker = false
        errorMessage = nil
    }

    /// 3D 모델 파일 추가
    public mutating func addAsset(fileURL: URL, fileName: String) {
        let asset = OperationAssetDisplayModel(
            id: UUID().uuidString,
            fileName: fileName,
            createdAt: Date(),
            fileURL: fileURL
        )
        assets.append(asset)
    }

    /// 3D 모델 파일 삭제
    public mutating func removeAsset(at index: Int) {
        guard assets.indices.contains(index) else { return }
        assets.remove(at: index)
    }

    /// 특정 에셋 삭제
    public mutating func removeAsset(id: String) {
        assets.removeAll { $0.id == id }
    }

    /// 폼 유효성 검증
    public var isValid: Bool {
        !title.isEmpty && !diagnosis.isEmpty && !surgeon.isEmpty && !surgicalSite.isEmpty
    }
}
