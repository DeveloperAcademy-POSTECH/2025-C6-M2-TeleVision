//
//  Demo3DVideoSource.swift
//  Hippo
//
//  3D Demo 모드에서 재생할 영상 소스 정의
//  기본 영상을 변경하려면 Demo3DDefaults.initialSource만 수정하면 됨
//

import Foundation

// MARK: - Demo 3D Video Source

/// 3D Demo 모드에서 재생할 영상 소스
/// - bird: 순한 영상 (기본값) - 새 영상
/// - endoscope: 내시경 수술 영상 (선택 시 전환)
public enum Demo3DVideoSource: String, CaseIterable, Equatable {
    case bird = "bird"
    case endoscope = "endoscope"

    /// 번들 내 리소스 파일명
    var resourceName: String {
        switch self {
        case .bird: return "bird-3d"
        case .endoscope: return "endoscope-demo"
        }
    }

    /// 파일 확장자
    var fileExtension: String {
        switch self {
        case .bird: return "mov"
        case .endoscope: return "mp4"
        }
    }

    /// 번들에서 URL 가져오기
    var bundleURL: URL? {
        Bundle.main.url(forResource: resourceName, withExtension: fileExtension)
    }

    /// UI 표시용 라벨 (짧게)
    var displayLabel: String {
        switch self {
        case .bird: return "General"
        case .endoscope: return "Endoscopic"
        }
    }
}

// MARK: - Demo 3D Defaults

/// 3D Demo 모드의 기본값 설정
/// 기본 영상을 변경하려면 initialSource 값만 수정하면 됨
public enum Demo3DDefaults {
    /// 3D Demo 모드 진입 시 기본 재생 소스
    public static let initialSource: Demo3DVideoSource = .endoscope
}
