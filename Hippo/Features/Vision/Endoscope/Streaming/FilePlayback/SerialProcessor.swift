//
//  SerialProcessor.swift
//  Hippo
//
//  Based on Apple's RealityKit-Playback-AVSampleBufferVideoRenderer sample
//  Modified to use callback pattern instead of direct videoRenderer injection
//

import AVFoundation
import CoreMedia
import CoreVideo
import VideoToolbox
import os

/// SBS 비디오 파일을 읽어서 스테레오 태그가 붙은 CMSampleBuffer로 변환
final class SerialProcessor {

    // MARK: - Properties

    /// 프레임 콜백 (렌더링 대신 외부로 전달)
    private let frameHandler: (CMSampleBuffer) -> Void

    /// Renderer 준비 상태 체크 (back-pressure 제어)
    private let isRendererReady: (() -> Bool)?

    /// 비디오 에셋
    private let asset: AVURLAsset

    /// 스테레오 메타데이터
    private let stereoMetadata: StereoMetadata

    /// 처리 중 여부
    private var isProcessing = false

    /// 로거
    private let logger = Logger(subsystem: "com.television.hippo", category: "SerialProcessor")

    // MARK: - Initialization

    /// SerialProcessor 초기화
    /// - Parameters:
    ///   - assetURL: SBS 비디오 파일 URL
    ///   - stereoMetadata: 스테레오 메타데이터 (기본값: .default)
    ///   - frameHandler: 프레임 콜백 (CMSampleBuffer 전달)
    ///   - isRendererReady: Renderer 준비 상태 체크 (back-pressure 제어)
    init(
        assetURL: URL,
        stereoMetadata: StereoMetadata = .default,
        frameHandler: @escaping (CMSampleBuffer) -> Void,
        isRendererReady: (() -> Bool)? = nil
    ) {
        self.asset = AVURLAsset(url: assetURL)
        self.stereoMetadata = stereoMetadata
        self.frameHandler = frameHandler
        self.isRendererReady = isRendererReady
        logger.info("SerialProcessor initialized with asset: \(assetURL.lastPathComponent)")
    }

    deinit {
        logger.info("SerialProcessor deallocated")
    }

    // MARK: - Public Methods

    /// 처리 시작
    func process() async throws {
        logger.info("SerialProcessor process() - begin")

        // 비디오 트랙 로드
        guard let videoTrack = try await asset.loadTracks(withMediaCharacteristic: .visual).first else {
            throw ProcessorError.noVideoTrack
        }

        let videoFrameSize = try await videoTrack.load(.naturalSize)
        logger.info("Video track size: \(Int(videoFrameSize.width))×\(Int(videoFrameSize.height))")

        // VTPixelTransferSession 생성
        var transferSession: VTPixelTransferSession?
        let sessionResult = VTPixelTransferSessionCreate(
            allocator: kCFAllocatorDefault,
            pixelTransferSessionOut: &transferSession
        )
        guard sessionResult == kCVReturnSuccess, let transferSession else {
            throw ProcessorError.transferSessionFailed(sessionResult)
        }
        VTSessionSetProperty(
            transferSession,
            key: kVTPixelTransferPropertyKey_ScalingMode,
            value: kVTScalingMode_CropSourceToCleanAperture
        )

        // 픽셀 버퍼 풀 생성
        let eyeFrameSize = CVImageSize(
            width: Int(videoFrameSize.width / stereoMetadata.horizontalScale),
            height: Int(videoFrameSize.height / stereoMetadata.verticalScale)
        )
        let creationAttributes = CVPixelBufferCreationAttributes(
            pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
            size: eyeFrameSize
        )
        guard let pixelBufferPool = try? CVMutablePixelBuffer.Pool(pixelBufferAttributes: creationAttributes) else {
            throw ProcessorError.pixelBufferPoolFailed
        }

        // AVAssetReader 생성
        let readerSettings: [String: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: String]()
        ]
        let videoTrackOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerSettings)
        let assetReader = try AVAssetReader(asset: asset)
        let videoTrackOutputProvider = assetReader.outputProvider(for: videoTrackOutput)
        try assetReader.start()

        // 프레임 처리 (완료될 때까지 대기)
        isProcessing = true
        var frameCount: Int = 0

        while !Task.isCancelled && isProcessing,
              let sampleBuffer = try await videoTrackOutputProvider.next() {

            if let transformedBuffer = try transform(
                from: sampleBuffer,
                with: pixelBufferPool,
                in: transferSession
            ) {
                // Back-pressure 체크
                if let readyCheck = isRendererReady {
                    var waitCount = 0
                    while !readyCheck() && !Task.isCancelled && isProcessing && waitCount < 30 {
                        try? await Task.sleep(nanoseconds: 16_000_000)
                        waitCount += 1
                    }
                    if !isProcessing { break }
                    if waitCount >= 30 { continue }
                }

                frameHandler(transformedBuffer)
                frameCount += 1

                if frameCount % 60 == 0 {
                    logger.debug("Processed \(frameCount) frames")
                }
            }
        }

        isProcessing = false
        logger.info("Processing complete. Total frames: \(frameCount), cancelled: \(Task.isCancelled)")

        assetReader.cancelReading()
        VTPixelTransferSessionInvalidate(transferSession)
    }

    /// 처리 취소
    func cancel() {
        isProcessing = false
        logger.info("SerialProcessor cancel()")
    }

    // MARK: - Private Methods

    /// SBS 프레임을 스테레오 태그 버퍼로 변환
    private func transform(
        from sourceSampleBuffer: CMReadySampleBuffer<CMSampleBuffer.DynamicContent>,
        with pixelBufferPool: CVMutablePixelBuffer.Pool,
        in transferSession: VTPixelTransferSession
    ) throws -> CMSampleBuffer? {
        var transformedBuffer: CMSampleBuffer? = nil

        try sourceSampleBuffer.withUnsafeSampleBuffer { cmSampleBuffer in
            guard let sourceImageBuffer = CMSampleBufferGetImageBuffer(cmSampleBuffer) else {
                throw ProcessorError.noImageBuffer
            }

            let layerIDs = [0, 1]
            let eyeComponents: [CMStereoViewComponents] = [.leftEye, .rightEye]
            var taggedBuffers = [CMTaggedDynamicBuffer]()

            for (layerID, eye) in zip(layerIDs, eyeComponents) {
                let pixelBuffer = try pixelBufferPool.makeMutablePixelBuffer()

                // Clean Aperture로 좌/우 눈 크롭
                let bufferSize = pixelBufferPool.pixelBufferAttributes.size
                let apertureOffset = stereoMetadata.apertureOffset(for: bufferSize, layerID: layerID)
                let cropRectDict = [
                    kCVImageBufferCleanApertureHorizontalOffsetKey: apertureOffset.horizontal,
                    kCVImageBufferCleanApertureVerticalOffsetKey: apertureOffset.vertical,
                    kCVImageBufferCleanApertureWidthKey: bufferSize.width,
                    kCVImageBufferCleanApertureHeightKey: bufferSize.height
                ]
                CVBufferSetAttachment(
                    sourceImageBuffer,
                    kCVImageBufferCleanApertureKey,
                    cropRectDict as CFDictionary,
                    .shouldPropagate
                )

                // 픽셀 전송
                pixelBuffer.withUnsafeBuffer { cvPixelBuffer in
                    let transferResult = VTPixelTransferSessionTransferImage(
                        transferSession,
                        from: sourceImageBuffer,
                        to: cvPixelBuffer
                    )
                    guard transferResult == kCVReturnSuccess else {
                        logger.error("Pixel transfer failed for layer \(layerID): \(transferResult)")
                        return
                    }
                }

                // 스테레오 태그 생성
                let tags: [CMTag] = [
                    .videoLayerID(Int64(layerID)),
                    .stereoView(eye),
                    .mediaType(.video)
                ]
                taggedBuffers.append(
                    CMTaggedDynamicBuffer(
                        tags: tags,
                        content: .pixelBuffer(CVReadOnlyPixelBuffer(pixelBuffer))
                    )
                )
            }

            // CMSampleBuffer 생성
            let buffer = CMReadySampleBuffer(
                taggedBuffers: taggedBuffers,
                formatDescription: CMTaggedBufferGroupFormatDescription(taggedBuffers: taggedBuffers),
                presentationTimeStamp: cmSampleBuffer.presentationTimeStamp,
                duration: cmSampleBuffer.duration
            )
            buffer.withUnsafeSampleBuffer { buffer in
                transformedBuffer = buffer
            }
        }

        return transformedBuffer
    }
}

// MARK: - Errors

enum ProcessorError: Error {
    case noVideoTrack
    case transferSessionFailed(OSStatus)
    case pixelBufferPoolFailed
    case noImageBuffer
}
