//
//  RecordingManager.swift
//  Hippo
//
//  Created by 김현기 on 11/17/25.
//

import Dependencies
import Observation
import os.log
import ReplayKit

// ViewModel에 에러를 전달하기 위한 Error 타입 정의
enum RecordingError: Error, LocalizedError {
    case fileNotFound
    case systemError(Error)
    case systemStop(Error?)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            "Failed to save recording. The temporary file was not found."
        case let .systemError(error):
            "Error starting recording: \(error.localizedDescription)"
        case let .systemStop(error):
            "Recording stopped unexpectedly by system. \(error?.localizedDescription ?? "No error")"
        }
    }
}

@MainActor
@Observable
final class RecordingManager: NSObject, RPScreenRecorderDelegate {
    // MARK: - Dependencies

    @ObservationIgnored
    @Dependency(\.addRecordingToOperation) private var addRecordingToOperation

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.hippo.Vision.RecordingManager", category: "Recording")

    // MARK: - Private Properties

    private let recorder = RPScreenRecorder.shared()

    // MARK: - Properties

    var isAvailable: Bool = false
    var isRecording: Bool = false
    var isMicrophoneEnabled: Bool = false {
        didSet {
            recorder.isMicrophoneEnabled = isMicrophoneEnabled
        }
    }

    // MARK: - Elapsed Time Tracking

    public var recordingTimer: Timer?
    public var elapsedSeconds: Int = 0
    public var formattedElapsedTime: String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    // MARK: - Callbacks

    var onRecordingFinished: ((URL) -> Void)?
    var onRecordingFailed: ((Error) -> Void)?

    // MARK: - Initialization

    override init() {
        super.init()
        recorder.delegate = self
        isAvailable = recorder.isAvailable
        logger.debug("ReplayKit availability: \(self.isAvailable)")
    }

    // MARK: - Methods

    public func isRecordingStateChanged() {
        if isRecording {
            // 녹화 시작: 타이머 시작
            elapsedSeconds = 0
            recordingTimer?.invalidate()
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                Task { @MainActor in
                    self.elapsedSeconds += 1
                }
            }
        } else {
            setTimerReset()
        }
    }

    public func setTimerReset() {
        elapsedSeconds = 0
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    private func setRecordingState(active: Bool) {
        isRecording = active
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        guard recorder.isAvailable else {
            logger.error("ReplayKit is not available.")
            return
        }

        recorder.startRecording { error in
            Task {
                if let error = error {
                    self.logger.error("Error starting recording: \(error.localizedDescription)")
                    self.setRecordingState(active: false)
                    self.onRecordingFailed?(RecordingError.systemError(error))
                    return
                }
                self.setRecordingState(active: true)
            }
        }
    }

    private func stopRecording() {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = "recording-\(Date().timeIntervalSince1970).mp4"
        let outputURL = tempDirectory.appendingPathComponent(fileName)

        logger.debug("Will save temporary file to: \(outputURL.path)")

        // (Deprecated API 사용 - InAppRecording 프로젝트와 동일한 로직)
        recorder.stopRecording(withOutput: outputURL) { error in
            Task {
                await self.setRecordingState(active: false)

                if let error = error {
                    print("Error received in stopRecording handler: \(error.localizedDescription)")
                }

                if FileManager.default.fileExists(atPath: outputURL.path) {
                    self.logger.debug("Successfully confirmed temp file exists at \(outputURL.path)")
                    await self.onRecordingFinished?(outputURL)
                } else {
                    self.logger.error("Failed to save recording. Temp file does not exist.")
                    await self.onRecordingFailed?(RecordingError.fileNotFound)
                }
            }
        }
    }

    public func addRecordingToOperation(operationID: String, patientID: String, tempURL: URL) async {
        do {
            let videoData = try Data(contentsOf: tempURL)

            let thumbnailImage = await generateThumbnail(for: tempURL)
            let thumbnailData = thumbnailImage?.pngData()

            let recording = OperationRecording(
                videoData: videoData,
                thumbnailData: thumbnailData,
                createdAt: Date()
            )

            try await addRecordingToOperation.run(
                AddRecordingToOperation.Input(
                    patientID: patientID,
                    operationID: operationID,
                    recording: recording
                )
            )

            try FileManager.default.removeItem(at: tempURL)
        } catch {
            logger.error("Error adding recording to operation: \(error.localizedDescription)")
        }
    }

    private func generateThumbnail(for url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        do {
            let cgImage = try await generator.image(at: CMTime(seconds: 1, preferredTimescale: 60)).image
            return UIImage(cgImage: cgImage)
        } catch {
            print("Error generating thumbnail: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - RPScreenRecorderDelegate

    nonisolated func screenRecorderDidChangeAvailability(_ screenRecorder: RPScreenRecorder) {
        Task { @MainActor in
            isAvailable = screenRecorder.isAvailable
        }
    }

    nonisolated func screenRecorder(_: RPScreenRecorder, didStopRecordingWith _: RPPreviewViewController?, error: Error?) {
        Task { @MainActor in
            if self.isRecording {
                print("Recording stopped unexpectedly by system. Error: \(error?.localizedDescription ?? "No error")")
                self.setRecordingState(active: false)
                self.onRecordingFailed?(RecordingError.systemStop(error))
            }
        }
    }
}
