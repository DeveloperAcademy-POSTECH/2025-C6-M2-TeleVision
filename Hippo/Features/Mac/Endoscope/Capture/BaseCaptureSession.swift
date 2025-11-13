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

    // MARK: Timestamp Generation

    private var captureStartTime: CFTimeInterval?
    private var frameNumber: Int64 = 0

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

    public func start(settings: CaptureSettings? = nil) throws {
        guard !isRunning else {
            logger.info("📹 [\(self.source.rawValue)] Already running")
            return
        }

        logger.info("📹 [\(self.source.rawValue)] Starting capture session...")

        let device = try findCaptureDevice()
        self.captureDevice = device

        logger.info("📹 [\(self.source.rawValue)] Found device: \(device.localizedName)")

        // If no settings provided, use device's native best format
        let finalSettings: CaptureSettings
        if let settings = settings {
            finalSettings = settings
        } else {
            finalSettings = selectBestNativeFormat(for: device)
        }

        try configureDevice(device, settings: finalSettings)

        let input = try AVCaptureDeviceInput(device: device)
        self.deviceInput = input

        let output = createVideoOutput(settings: finalSettings)
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

    // MARK: - Private Methods: Native Format Selection

    /// Selects the best native format from the device
    /// Prioritizes: highest resolution, then highest frame rate, then NV12 pixel format
    private func selectBestNativeFormat(for device: AVCaptureDevice) -> CaptureSettings {
        logger.info("🔍 [\(self.source.rawValue)] Selecting best native format for device...")

        // Find the format with highest resolution
        let bestFormat = device.formats
            .filter { format in
                // Prefer NV12 format (4:2:0 YUV) for efficient encoding
                let pixelFormat = CMFormatDescriptionGetMediaSubType(format.formatDescription)
                return pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange ||
                       pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            }
            .max { format1, format2 in
                let dims1 = CMVideoFormatDescriptionGetDimensions(format1.formatDescription)
                let dims2 = CMVideoFormatDescriptionGetDimensions(format2.formatDescription)

                // Compare by total pixel count
                let pixels1 = Int(dims1.width) * Int(dims1.height)
                let pixels2 = Int(dims2.width) * Int(dims2.height)

                return pixels1 < pixels2
            }

        guard let format = bestFormat else {
            logger.warning("⚠️ [\(self.source.rawValue)] No suitable format found, using fallback")
            return .standard
        }

        let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        let pixelFormat = CMFormatDescriptionGetMediaSubType(format.formatDescription)

        // Get max FPS for this format
        let maxFPS = format.videoSupportedFrameRateRanges
            .map { 1.0 / CMTimeGetSeconds($0.minFrameDuration) }
            .max() ?? 30.0

        // Round to standard FPS values
        let standardFPS: [Int] = [60, 30, 24, 15]
        let selectedFPS = standardFPS.first { Double($0) <= maxFPS } ?? 30

        logger.info("✅ [\(self.source.rawValue)] Selected native format: \(dimensions.width)×\(dimensions.height)@\(selectedFPS)fps")

        return CaptureSettings(
            width: Int(dimensions.width),
            height: Int(dimensions.height),
            frameRate: selectedFPS,
            pixelFormat: pixelFormat
        )
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
            logger.warning("   Available formats:")
            for (idx, fmt) in device.formats.enumerated() {
                let dims = CMVideoFormatDescriptionGetDimensions(fmt.formatDescription)
                let pixelFmt = CMFormatDescriptionGetMediaSubType(fmt.formatDescription)
                logger.warning("   [\(idx)] \(dims.width)×\(dims.height) format=\(pixelFmt)")
            }
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
            logger.warning("⚠️ [\(self.source.rawValue)] Frame rate \(settings.frameRate) not supported, using default")
            logger.warning("   Requested: \(settings.frameRate) fps")
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

        // Initialize start time on first frame
        if captureStartTime == nil {
            let hostTime = mach_absolute_time()
            var timebaseInfo = mach_timebase_info_data_t()
            mach_timebase_info(&timebaseInfo)
            let nanoseconds = hostTime * UInt64(timebaseInfo.numer) / UInt64(timebaseInfo.denom)
            captureStartTime = Double(nanoseconds) / 1_000_000_000.0
        }

        // Generate synthetic timestamp based on frame number and expected FPS
        // This ensures perfectly regular intervals regardless of actual capture timing
        let expectedFrameDuration = 1.0 / 30.0  // 30 fps = 33.33ms per frame
        let syntheticTimestamp = (captureStartTime ?? 0) + (Double(frameNumber) * expectedFrameDuration)
        let pts = CMTime(seconds: syntheticTimestamp, preferredTimescale: 1000000)
        frameNumber += 1

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
