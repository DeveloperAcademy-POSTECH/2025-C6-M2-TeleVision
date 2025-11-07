//
//  BaseCaptureSession.swift
//  Hippo
//
//  Base class for UVC camera capture using AVFoundation
//  Configures AVCaptureSession for 1920×1080@60fps NV12 capture
//

import Foundation
import AVFoundation
import CoreMedia
import CoreVideo
import os.log

// MARK: - Base Capture Session

open class BaseCaptureSession: NSObject {

    // MARK: Properties

    public let source: CaptureSource
    public weak var delegate: CaptureOutputDelegate?

    /// If set, device selection will prefer the device with this uniqueID.
    public var preferredDeviceUniqueID: String?

    private let session: AVCaptureSession
    private var deviceInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let outputQueue: DispatchQueue

    private let logger = Logger(subsystem: "com.television.hippo", category: "Capture")

    // MARK: State

    private(set) var isRunning: Bool = false
    private var captureDevice: AVCaptureDevice?

    // MARK: Statistics

    private var frameCount: Int = 0
    private var lastStatsTime: Date = Date()

    // MARK: Initialization

    public init(source: CaptureSource, preferredDeviceUniqueID: String? = nil) {
        self.source = source
        self.preferredDeviceUniqueID = preferredDeviceUniqueID
        self.session = AVCaptureSession()
        self.outputQueue = DispatchQueue(
            label: "com.television.hippo.capture.\(source.rawValue)",
            qos: .userInteractive
        )

        super.init()
    }

    deinit {
        stop()
    }

    // MARK: - Public Methods

    public func start(settings: CaptureSettings = .standard) throws {
        guard !isRunning else {
            logger.info("📹 [\(self.source.rawValue)] Already running")
            return
        }

        logger.info("📹 [\(self.source.rawValue)] Starting capture session...")

        let device = try findCaptureDevice()
        self.captureDevice = device

        logger.info("📹 [\(self.source.rawValue)] Found device: \(device.localizedName)")

        try configureDevice(device, settings: settings)

        let input = try AVCaptureDeviceInput(device: device)
        self.deviceInput = input

        let output = createVideoOutput(settings: settings)
        self.videoOutput = output

        session.beginConfiguration()
        #if os(iOS)
        session.sessionPreset = .inputPriority
        #else
        session.sessionPreset = .high
        #endif

        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw VideoError.captureConfigurationFailed(reason: "Cannot add device input")
        }
        session.addInput(input)

        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            throw VideoError.captureConfigurationFailed(reason: "Cannot add video output")
        }
        session.addOutput(output)

        session.commitConfiguration()

        // Start running on background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
            self?.isRunning = true
            self?.logger.info("✅ [\(self?.source.rawValue ?? "")] Capture session started")
        }
    }

    public func stop() {
        guard isRunning else { return }

        logger.info("🛑 [\(self.source.rawValue)] Stopping capture session...")

        session.stopRunning()

        if let input = deviceInput {
            session.removeInput(input)
        }

        if let output = videoOutput {
            session.removeOutput(output)
        }

        deviceInput = nil
        videoOutput = nil
        captureDevice = nil
        isRunning = false

        logger.info("✅ [\(self.source.rawValue)] Capture session stopped")
    }

    // MARK: - Private Methods: Device Discovery

    private func findCaptureDevice() throws -> AVCaptureDevice {
        #if os(macOS)
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.externalUnknown, .builtInWideAngleCamera],
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

        let devices = discoverySession.devices

        // Prefer device with matching uniqueID
        if let preferredID = preferredDeviceUniqueID,
           let device = devices.first(where: { $0.uniqueID == preferredID }) {
            logger.info("📹 [\(self.source.rawValue)] Found preferred device: \(device.localizedName)")
            return device
        }

        // Fallback to first available device
        guard let device = devices.first else {
            throw VideoError.noCameraAvailable(source: source)
        }

        return device
    }

    // MARK: - Private Methods: Configuration

    private func configureDevice(_ device: AVCaptureDevice, settings: CaptureSettings) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        // Find matching format
        let targetFormat = device.formats.first { format in
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let pixelFormat = CMFormatDescriptionGetMediaSubType(format.formatDescription)

            return dimensions.width == settings.width &&
                   dimensions.height == settings.height &&
                   pixelFormat == settings.pixelFormat
        }

        guard let format = targetFormat else {
            logger.warning("⚠️ [\(self.source.rawValue)] Exact format not found, using default")
            // Don't throw, use default format
            return
        }

        device.activeFormat = format

        // Configure frame rate
        let targetFrameDuration = CMTime(value: 1, timescale: CMTimeScale(settings.frameRate))

        if format.videoSupportedFrameRateRanges.contains(where: { range in
            range.minFrameDuration <= targetFrameDuration &&
            range.maxFrameDuration >= targetFrameDuration
        }) {
            device.activeVideoMinFrameDuration = targetFrameDuration
            device.activeVideoMaxFrameDuration = targetFrameDuration
            logger.info("✅ [\(self.source.rawValue)] Frame rate set to \(settings.frameRate) fps")
        } else {
            logger.warning("⚠️ [\(self.source.rawValue)] Frame rate \(settings.frameRate) not supported")
        }

        logger.info("✅ [\(self.source.rawValue)] Device configured: \(settings.width)×\(settings.height)@\(settings.frameRate)fps")
    }

    private func createVideoOutput(settings: CaptureSettings) -> AVCaptureVideoDataOutput {
        let output = AVCaptureVideoDataOutput()

        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: settings.pixelFormat
        ]

        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: outputQueue)

        return output
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension BaseCaptureSession: AVCaptureVideoDataOutputSampleBufferDelegate {

    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            logger.error("❌ [\(self.source.rawValue)] Failed to get pixel buffer")
            return
        }

        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        // Update statistics
        frameCount += 1
        if frameCount % 300 == 0 {  // Log every 5 seconds at 60fps
            let now = Date()
            let elapsed = now.timeIntervalSince(lastStatsTime)
            let fps = Double(frameCount) / elapsed

            logger.info("📊 [\(self.source.rawValue)] FPS: \(String(format: "%.1f", fps))")

            frameCount = 0
            lastStatsTime = now
        }

        // Notify delegate
        delegate?.didOutput(pixelBuffer: pixelBuffer, pts: pts, source: source)
    }

    public func captureOutput(
        _ output: AVCaptureOutput,
        didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        logger.warning("⚠️ [\(self.source.rawValue)] Dropped frame")
    }
}
