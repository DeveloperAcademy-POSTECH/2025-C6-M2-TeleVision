//
//  StreamingControlViewModel.swift
//  HippoMac
//
//  ViewModel for streaming control interface
//

import Foundation
import AVFoundation
import Observation
import CoreVideo
import CoreMedia
import os.log

// MARK: - Sendable Wrapper

/// Thread-safe wrapper for CVPixelBuffer
fileprivate struct SendablePixelBuffer: @unchecked Sendable {
    nonisolated(unsafe) let pixelBuffer: CVPixelBuffer

    nonisolated init(_ pixelBuffer: CVPixelBuffer) {
        self.pixelBuffer = pixelBuffer
    }
}

// MARK: - StreamingControlViewModel

/// Streaming control view model
@MainActor
@Observable
public final class StreamingControlViewModel {

    // MARK: - Dependencies

    private var leftCapture: LeftCaptureSession?
    private var rightCapture: RightCaptureSession?
    private var frameSync: FrameSync?
    private var composer: CI_SBSComposer?
    private var transport: WebRTCManager?

    // Signaling client for auto-start (always connected, waiting for receiver)
    private var signalingClient: SignalingClient?

    // Preview display layer (set from view)
    public var previewLayer: AVSampleBufferDisplayLayer?

    private let logger = Logger(subsystem: "com.television.hippo", category: "StreamingControl")

    // MARK: - State: Video & Camera Mode

    var videoMode: VideoMode = .halfSBS {
        didSet {
            logger.info("Video mode changed: \(oldValue.rawValue) → \(self.videoMode.rawValue)")

            // Single 카메라일 때는 Mono로만 가능
            if cameraInputMode == .single && videoMode != .mono {
                videoMode = .mono
                return
            }

            // Mono 모드일 때는 Single 카메라만 가능
            if videoMode == .mono && cameraInputMode != .single {
                cameraInputMode = .single
                return  // cameraInputMode didSet에서 재시작하므로 여기서는 return
            }

            // 스트리밍 중이면 재시작
            if isStreaming {
                logger.info("Restarting streaming due to video mode change...")
                Task {
                    stopStreaming()
                    try? await Task.sleep(for: .milliseconds(500))
                    try? await startStreaming()
                }
            }
        }
    }

    var scalingMode: ScalingMode = .quarter {
        didSet {
            logger.info("Scaling mode changed: \(oldValue.rawValue) → \(self.scalingMode.rawValue)")

            // 스트리밍 중이면 재시작
            if isStreaming {
                logger.info("Restarting streaming due to scaling mode change...")
                Task {
                    stopStreaming()
                    try? await Task.sleep(for: .milliseconds(500))
                    try? await startStreaming()
                }
            }
        }
    }

    var isHalfBitrateEnabled: Bool = true {
        didSet {
            logger.info("Bitrate mode changed: \(oldValue ? "15 Mbps" : "30 Mbps") → \(self.isHalfBitrateEnabled ? "15 Mbps" : "30 Mbps")")

            // 스트리밍 중이면 재시작
            if isStreaming {
                logger.info("Restarting streaming due to bitrate change...")
                Task {
                    stopStreaming()
                    try? await Task.sleep(for: .milliseconds(500))
                    try? await startStreaming()
                }
            }
        }
    }

    var cameraInputMode: CameraInputMode = .dual {
        didSet {
            logger.info("Camera input mode changed: \(oldValue.rawValue) → \(self.cameraInputMode.rawValue)")

            // Single로 변경되면 자동으로 Mono로 설정
            if cameraInputMode == .single {
                if videoMode != .mono {
                    videoMode = .mono
                    return  // videoMode didSet에서 재시작하므로 여기서는 return
                }
            } else {
                // Dual로 변경되면 stereo 모드로 설정
                if videoMode == .mono {
                    videoMode = .fullSBS
                    return  // videoMode didSet에서 재시작하므로 여기서는 return
                }
            }

            // 스트리밍 중이면 재시작 (videoMode가 변경되지 않은 경우만)
            if isStreaming {
                logger.info("Restarting streaming due to camera input mode change...")
                Task {
                    stopStreaming()
                    try? await Task.sleep(for: .milliseconds(500))
                    try? await startStreaming()
                }
            }
        }
    }

    // MARK: - State: Camera Devices

    /// 사용 가능한 모든 카메라 장치
    var availableDevices: [AVCaptureDevice] = []

    /// DualInput용 선택된 장치
    var selectedLeftDevice: AVCaptureDevice?
    var selectedRightDevice: AVCaptureDevice?

    /// SingleInput용 선택된 장치
    var selectedSingleDevice: AVCaptureDevice?

    // MARK: - State: Streaming

    var isStreaming: Bool = false
    var errorMessage: String?

    // MARK: - State: Signaling Connection

    /// 시그널링 서버 연결 상태
    var isSignalingConnected: Bool = false
    /// Receiver(Vision Pro) 준비 상태
    var isReceiverReady: Bool = false

    // MARK: - State: Inspector Settings

    var normalizationPolicy: NormalizePolicy = .cropToMatchAspect
    var targetBitrate: Double = 15.0  // Mbps

    // MARK: - State: Statistics

    var leftCaptureFPS: Double = 0.0
    var rightCaptureFPS: Double = 0.0
    var syncPairsFPS: Double = 0.0
    var syncDropsFPS: Double = 0.0
    var networkBitrate: Double = 0.0
    var encodeFPS: Double = 0.0
    var captureLatency: Double = 0.0
    var composeLatency: Double = 0.0
    var encodeLatency: Double = 0.0
    var e2eLatency: Double = 0.0

    // MARK: - State: Inspector UI

    var isInspectorPresented: Bool = false

    // MARK: - Initialization

    init() {
        loadAvailableDevices()
        connectToSignalingServer()
    }

    // MARK: - Signaling Server Connection

    /// 시그널링 서버에 연결 (앱 시작 시 자동 호출)
    private func connectToSignalingServer() {
        let serverURL = URL(string: "ws://127.0.0.1:8080")!
        logger.info("Connecting to signaling server: \(serverURL.absoluteString)")

        signalingClient = SignalingClient(serverURL: serverURL)
        signalingClient?.delegate = self

        do {
            try signalingClient?.connect(as: "sender")
        } catch {
            logger.error("Failed to connect to signaling server: \(error.localizedDescription)")
            errorMessage = "시그널링 서버 연결 실패"
        }
    }

    /// 시그널링 서버 연결 해제
    private func disconnectFromSignalingServer() {
        signalingClient?.disconnect()
        signalingClient = nil
        isSignalingConnected = false
        isReceiverReady = false
    }

    /// 시그널링 서버 재연결
    func reconnectToSignalingServer() {
        disconnectFromSignalingServer()
        connectToSignalingServer()
    }

    // MARK: - Public Methods: Device Management

    /// 사용 가능한 카메라 장치 목록을 로드합니다
    func loadAvailableDevices() {
        Task { @MainActor in
            #if os(macOS)
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.external, .builtInWideAngleCamera],
                mediaType: .video,
                position: .unspecified
            )
            #else
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera],
                mediaType: .video,
                position: .back
            )
            #endif

            availableDevices = discoverySession.devices

            print("[Device Discovery] Found \(availableDevices.count) devices")
            for (index, device) in availableDevices.enumerated() {
                print("  [\(index)] \(device.localizedName) - ID: \(device.uniqueID)")
            }

            // 기본 장치 선택
            if availableDevices.count >= 2 {
                selectedLeftDevice = availableDevices[0]
                selectedRightDevice = availableDevices[1]
                selectedSingleDevice = availableDevices[0]
                print("[Device Selection] Left: \(selectedLeftDevice?.localizedName ?? "nil"), Right: \(selectedRightDevice?.localizedName ?? "nil")")
            } else if let firstDevice = availableDevices.first {
                selectedLeftDevice = firstDevice
                selectedRightDevice = firstDevice
                selectedSingleDevice = firstDevice
                print("[Device Selection] Single device: \(firstDevice.localizedName)")
            } else {
                print("[Device Selection] No devices found")
            }
        }
    }

    /// 장치 목록을 새로고침합니다
    func refreshDevices() {
        loadAvailableDevices()
    }

    // MARK: - Public Methods: Streaming Control

    /// 스트리밍을 시작합니다
    func startStreaming() async throws {
        guard !isStreaming else { return }

        errorMessage = nil

        do {
            switch videoMode {
            case .fullSBS, .halfSBS:
                try await startStereoStreaming()
            case .mono:
                try await startMonoStreaming()
            }

            isStreaming = true
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// 스트리밍을 중지합니다
    func stopStreaming() {
        guard isStreaming else { return }

        leftCapture?.stop()
        rightCapture?.stop()

        // Reset FrameSync buffers before stopping
        frameSync?.reset()

        transport?.stop()

        leftCapture = nil
        rightCapture = nil
        frameSync = nil
        composer = nil
        transport = nil

        // Clear preview
        if let layer = previewLayer {
            if #available(macOS 15.0, *) {
                layer.sampleBufferRenderer.flush()
            } else {
                layer.flush()
            }
        }

        isStreaming = false
        isReceiverReady = false  // Reset receiver ready state

        // 통계 초기화
        resetStatistics()

        logger.info("Streaming stopped")
    }

    // MARK: - Private Methods: Streaming Setup

    private func startStereoStreaming() async throws {
        switch cameraInputMode {
        case .dual:
            try await startDualInputCapture()
        case .single:
            try await startSingleInputCapture()
        }
    }

    private func startDualInputCapture() async throws {
        guard let leftDevice = selectedLeftDevice,
              let rightDevice = selectedRightDevice else {
            throw StreamingError.noDeviceSelected
        }

        logger.info("Starting dual camera capture...")

        // Find common capture settings for both cameras
        let captureSettings = CaptureSettings.findCommonSettings(
            for: [leftDevice, rightDevice]
        ) ?? .standard

        logger.info("Using capture settings: \(captureSettings.width)×\(captureSettings.height)@\(captureSettings.frameRate)fps")

        // Initialize components
        let sync = FrameSync()
        let comp = CI_SBSComposer()
        let webrtc = WebRTCManager(config: isHalfBitrateEnabled ? .lowBandwidth : .standard)

        self.frameSync = sync
        self.composer = comp
        self.transport = webrtc

        // Setup frame sync callback
        sync.onPair = { [weak self] pair in
            Task { @MainActor in
                await self?.handleSyncedPair(pair)
            }
        }

        // Left camera 시작
        let leftSession = LeftCaptureSession(preferredDeviceUniqueID: leftDevice.uniqueID)
        leftSession.delegate = self
        try leftSession.start(settings: captureSettings)
        self.leftCapture = leftSession

        // Right camera 시작
        let rightSession = RightCaptureSession(preferredDeviceUniqueID: rightDevice.uniqueID)
        rightSession.delegate = self
        try rightSession.start(settings: captureSettings)
        self.rightCapture = rightSession

        // Start WebRTC transport with external signaling client
        guard let signalingClient = signalingClient else {
            throw StreamingError.networkError("시그널링 서버에 연결되지 않았습니다")
        }
        try webrtc.start(with: signalingClient)

        logger.info("Dual camera capture started")
    }

    private func startSingleInputCapture() async throws {
        guard let device = selectedSingleDevice else {
            throw StreamingError.noDeviceSelected
        }

        // Single camera 시작 (SBS 영상을 한 카메라에서)
        let leftSession = LeftCaptureSession(preferredDeviceUniqueID: device.uniqueID)
        try leftSession.start(settings: .standard)
        self.leftCapture = leftSession

        // TODO: Setup SBS splitter & composer
        // TODO: Setup WebRTC transport
    }

    private func startMonoStreaming() async throws {
        guard let device = selectedSingleDevice else {
            throw StreamingError.noDeviceSelected
        }

        logger.info("Starting mono capture...")

        // Initialize WebRTC transport
        let webrtc = WebRTCManager(config: isHalfBitrateEnabled ? .lowBandwidth : .standard)
        self.transport = webrtc

        // Mono video 시작 - settings를 전달하지 않아 카메라의 네이티브 해상도 사용
        let leftSession = LeftCaptureSession(preferredDeviceUniqueID: device.uniqueID)
        leftSession.delegate = self
        try leftSession.start()  // No settings = use native resolution
        self.leftCapture = leftSession

        // Start WebRTC transport with external signaling client
        guard let signalingClient = signalingClient else {
            throw StreamingError.networkError("시그널링 서버에 연결되지 않았습니다")
        }
        try webrtc.start(with: signalingClient)

        logger.info("Mono capture started with native resolution")
    }

    // MARK: - Private Methods: Frame Handling

    /// OPTIMIZED: Preview frame throttling for reduced CPU usage
    private var lastPreviewTime: CFAbsoluteTime = 0
    private let previewFrameInterval: CFTimeInterval = 1.0 / 30.0  // 30fps max for preview

    private func handleSyncedPair(_ pair: SyncedPair) async {
        guard let composer = self.composer else {
            logger.error("Composer is nil in handleSyncedPair")
            return
        }

        do {
            // Determine SBS mode from video mode
            let sbsMode: SBSMode = switch videoMode {
            case .fullSBS: .full1080
            case .halfSBS: .half1080
            case .mono: .full1080  // Fallback (shouldn't reach here)
            }

            // Compose SBS frame
            let config = SBSComposerConfig(
                mode: sbsMode,
                policy: normalizationPolicy,
                colorSpace: CGColorSpace(name: CGColorSpace.itur_709),
                scalingMode: scalingMode
            )

            let composed = try composer.compose(
                left: pair.left,
                right: pair.right,
                leftSize: pair.leftSize,
                rightSize: pair.rightSize,
                config: config
            )

            // Send via WebRTC
            transport?.send(pixelBuffer: composed, presentationTime: pair.pts)

            // OPTIMIZED: Update preview at reduced framerate (30fps max)
            await updatePreviewThrottled(composed, pts: pair.pts)

        } catch {
            logger.error("Composition failed: \(error.localizedDescription)")
        }
    }

    private func handleMonoFrame(_ pixelBuffer: CVPixelBuffer, pts: CMTime) async {
        // Send directly via WebRTC (no composition needed)
        transport?.send(pixelBuffer: pixelBuffer, presentationTime: pts)

        // OPTIMIZED: Update preview at reduced framerate (30fps max)
        await updatePreviewThrottled(pixelBuffer, pts: pts)
    }

    /// OPTIMIZED: Throttled preview update to limit to 30fps
    @MainActor
    private func updatePreviewThrottled(_ pixelBuffer: CVPixelBuffer, pts: CMTime) async {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastPreviewTime >= previewFrameInterval else {
            // Skip frame to maintain 30fps cap
            return
        }
        lastPreviewTime = now

        await updatePreview(pixelBuffer, pts: pts)
    }

    /// OPTIMIZED: Preview rendering with autoreleasepool and reduced overhead
    @MainActor
    private func updatePreview(_ pixelBuffer: CVPixelBuffer, pts: CMTime) async {
        guard let layer = previewLayer else { return }

        // OPTIMIZED: Use autoreleasepool to prevent memory accumulation
        autoreleasepool {
            // Create sample buffer from pixel buffer
            var sampleBuffer: CMSampleBuffer?
            var timingInfo = CMSampleTimingInfo(
                duration: .invalid,
                presentationTimeStamp: pts,
                decodeTimeStamp: .invalid
            )

            var formatDescription: CMFormatDescription?
            let status = CMVideoFormatDescriptionCreateForImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: pixelBuffer,
                formatDescriptionOut: &formatDescription
            )

            guard status == noErr, let formatDesc = formatDescription else {
                logger.error("Failed to create format description")
                return
            }

            let sampleStatus = CMSampleBufferCreateReadyWithImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: pixelBuffer,
                formatDescription: formatDesc,
                sampleTiming: &timingInfo,
                sampleBufferOut: &sampleBuffer
            )

            guard sampleStatus == noErr, let sample = sampleBuffer else {
                logger.error("Failed to create sample buffer")
                return
            }

            // Enqueue to display layer
            if #available(macOS 15.0, *) {
                layer.sampleBufferRenderer.enqueue(sample)

                // Flush if layer is not ready
                if layer.sampleBufferRenderer.status == .failed {
                    logger.warning("Display layer failed, flushing...")
                    layer.sampleBufferRenderer.flush()
                }
            } else {
                layer.enqueue(sample)

                // Flush if layer is not ready
                if layer.status == .failed {
                    logger.warning("Display layer failed, flushing...")
                    layer.flush()
                }
            }
        }  // OPTIMIZED: autoreleasepool ensures immediate cleanup
    }

    // MARK: - Private Methods: Statistics

    private func resetStatistics() {
        leftCaptureFPS = 0.0
        rightCaptureFPS = 0.0
        syncPairsFPS = 0.0
        syncDropsFPS = 0.0
        networkBitrate = 0.0
        encodeFPS = 0.0
        captureLatency = 0.0
        composeLatency = 0.0
        encodeLatency = 0.0
        e2eLatency = 0.0
    }

    // MARK: - Public Methods: Inspector

    func toggleInspector() {
        isInspectorPresented.toggle()
    }
}

// MARK: - CaptureOutputDelegate

extension StreamingControlViewModel: CaptureOutputDelegate {
    nonisolated public func didOutput(pixelBuffer: CVPixelBuffer, pts: CMTime, source: CaptureSource) {
        // Wrap CVPixelBuffer to safely cross actor boundary
        let sendableBuffer = SendablePixelBuffer(pixelBuffer)
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            // Ignore frames when not streaming (during shutdown)
            guard self.isStreaming else { return }

            if self.videoMode == .mono {
                // Mono mode: send frame directly
                if source == .left {  // Only process left camera in mono mode
                    await self.handleMonoFrame(sendableBuffer.pixelBuffer, pts: pts)
                }
            } else {
                // Stereo mode: push to frame sync
                if self.frameSync == nil {
                    self.logger.error("FrameSync is nil in stereo mode! Mode: \(self.videoMode.rawValue), Source: \(source.rawValue)")
                } else {
                    self.frameSync?.push(sendableBuffer.pixelBuffer, pts: pts, source: source)
                }
            }
        }
    }

    nonisolated public func didEncounterError(_ error: Error, source: CaptureSource) {
        Task { @MainActor in
            self.logger.error("Capture error [\(source.rawValue)]: \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - SignalingDelegate

extension StreamingControlViewModel: SignalingDelegate {
    nonisolated public func signalingClient(_ client: SignalingClient, didChangeState state: SignalingState) {
        Task { @MainActor in
            switch state {
            case .connected:
                self.logger.info("✅ Signaling server connected")
                self.isSignalingConnected = true
                self.errorMessage = nil
            case .disconnected:
                self.logger.info("Signaling server disconnected")
                self.isSignalingConnected = false
                self.isReceiverReady = false
            case .connecting:
                self.logger.info("Connecting to signaling server...")
            case .failed:
                self.logger.error("❌ Signaling server connection failed")
                self.isSignalingConnected = false
                self.isReceiverReady = false
                self.errorMessage = "시그널링 서버 연결 실패"
            }
        }
    }

    nonisolated public func signalingClientDidReceiveReceiverReady(_ client: SignalingClient) {
        Task { @MainActor in
            self.logger.info("🎉 Receiver (Vision Pro) is ready! Auto-starting streaming...")
            self.isReceiverReady = true

            // 자동으로 스트리밍 시작
            if !self.isStreaming {
                do {
                    try await self.startStreaming()
                } catch {
                    self.logger.error("Failed to auto-start streaming: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // WebRTC signaling messages - forward to WebRTCManager
    nonisolated public func signalingClient(_ client: SignalingClient, didReceiveOffer sdp: String) {
        // Sender doesn't receive offers
    }

    nonisolated public func signalingClient(_ client: SignalingClient, didReceiveAnswer sdp: String) {
        Task { @MainActor in
            self.transport?.handleAnswer(sdp: sdp)
        }
    }

    nonisolated public func signalingClient(_ client: SignalingClient, didReceiveCandidate candidate: String, sdpMid: String?, sdpMLineIndex: Int32) {
        Task { @MainActor in
            self.transport?.handleRemoteCandidate(candidate: candidate, sdpMid: sdpMid, sdpMLineIndex: sdpMLineIndex)
        }
    }

    nonisolated public func signalingClientDidReceiveRenegotiate(_ client: SignalingClient) {
        // Handle renegotiation if needed
    }
}

// MARK: - Supporting Types

enum StreamingError: LocalizedError {
    case noDeviceSelected
    case captureSessionFailed(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .noDeviceSelected:
            return "카메라 장치가 선택되지 않았습니다."
        case .captureSessionFailed(let reason):
            return "카메라 캡처 실패: \(reason)"
        case .networkError(let reason):
            return "네트워크 오류: \(reason)"
        }
    }
}
