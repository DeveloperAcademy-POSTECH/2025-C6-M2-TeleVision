//
//  EndoscopeFrameSource.swift
//  Hippo
//
//  Frame source abstraction for Endoscope streaming
//  Allows WebRTC-based and file-based sources to share the same pipeline
//

import Foundation
import AVFoundation

/// 내시경 프레임 입력 소스 추상화
/// WebRTC 기반 소스와 파일 기반 소스를 동일한 인터페이스로 처리
public protocol EndoscopeFrameSource: AnyObject {
    /// CMSampleBuffer 단위 프레임 콜백
    var onFrame: ((CMSampleBuffer) -> Void)? { get set }

    /// 소스 시작 (WebRTC 연결 or 파일 재생)
    func start() async throws

    /// 소스 정지 (WebRTC 연결 해제 or 파일 재생 정지)
    func stop()
}
