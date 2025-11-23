//
//  RecordingViewModel.swift
//  Hippo
//
//  Created by 김현기 on 11/17/25.
//

import AVKit
import Observation
import SwiftUI

@MainActor
@Observable
class RecordingViewModel {
    /// The scene used to present the video.
    var scene: UIScene?

    var recordings: [OperationRecording] = []

    /// An object that controls the playback of a video.
    var player = AVPlayer()
    /// An object that provides the playback user interface.
    var playerViewController: AVPlayerViewController?

    /// Creates a player model.
    init() {
        configureAudio()
    }

    // MARK: Playback configuration

    /// Plays a video in the system playback interface.
    /// - Parameters:
    ///   - video: The video to play.
    func playRecord(_ record: OperationRecording) {
        loadVideo(record)
        configurePlaybackUI()
        Task { await presentPlayer() }
    }

    /// Loads the video for playback.
    /// - Parameter video: The video to play.
    private func loadVideo(_ record: OperationRecording) {
        let fileManager = FileManager.default
        let tempURL = fileManager.temporaryDirectory
            .appendingPathComponent("\(record.id).mp4")

        do {
            // videoData를 디스크에 임시 파일로 쓰기
            try record.videoData.write(to: tempURL, options: .atomic)

            player = AVPlayer(url: tempURL)
        } catch {
            print("Error writing temporary video file: \(error.localizedDescription)")
        }

        // Create a new player item for the video.
        let playerItem = AVPlayerItem(url: tempURL)
        // Set external metadata on the player item for the current video.
        playerItem.externalMetadata = createMetadataItems(for: record)
        // Load the player item into the player and begin queueing its data.
        player.replaceCurrentItem(with: playerItem)
    }

    /// Create and configure a player view controller and its related experience controller.
    private func configurePlaybackUI() {
        let controller = AVPlayerViewController()

        // Configure the experience controller with the system-recommended set of experiences.
        let experienceController = controller.experienceController
        experienceController.allowedExperiences = .recommended()
        experienceController.delegate = self

        // Connect the player object to the player view controller.
        controller.player = player

        // Store the controller reference.
        playerViewController = controller
    }

    /// Presents a video in the system playback interface.
    private func presentPlayer() async {
        /// Attempt transition from an `.embedded` to an `.expanded` experience.
        switch await playerViewController?.experienceController.transition(to: .expanded) {
        case .completed:
            // Begin playback if the transition completes successfully.
            player.play()
        case let .reversed(reason: reason):
            print("Unable to start playback: \(reason).")
        default:
            fatalError()
        }
    }

    /// Creates metadata items from the video items data.
    /// - Parameter video: The video to create metadata for.
    /// - Returns: An array of `AVMetadataItem` to set on a player item.
    private func createMetadataItems(for record: OperationRecording) -> [AVMetadataItem] {
        let mapping: [AVMetadataIdentifier: Any] = [
            .commonIdentifierTitle: record.id,
            .commonIdentifierDescription: record.createdAt.toTimeString(),
            .commonIdentifierArtwork: record.thumbnailData ?? Data(),
        ]
        return mapping.compactMap { createMetadataItem(for: $0, value: $1) }
    }

    /// Creates a metadata item for a the specified identifier and value.
    /// - Parameters:
    ///   - identifier: An identifier for the item.
    ///   - value: A value to associate with the item.
    /// - Returns: A new `AVMetadataItem` object.
    private func createMetadataItem(for identifier: AVMetadataIdentifier,
                                    value: Any) -> AVMetadataItem
    {
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value as? NSCopying & NSObjectProtocol
        // Specify `und` to indicate an undefined language.
        item.extendedLanguageTag = "und"
        return item.copy() as! AVMetadataItem
    }

    // MARK: Audio configuration

    /// Configures the audio session for video playback.
    private func configureAudio() {
        do {
            // Configure the audio session for playback. Set the `moviePlayback` mode
            // to reduce the audio's dynamic range to help normalize audio levels.
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, policy: .longFormVideo)
            try session.setIntendedSpatialExperience(
                .headTracked(soundStageSize: .automatic, anchoringStrategy: .automatic)
            )
        } catch {
            print("Unable to configure audio session: \(error.localizedDescription)")
        }
    }

    // MARK: Internal state management

    // Clears any loaded media and resets the player model to its default state.
    private func resetState() {
        playerViewController = nil
        // Clear any loaded media.
        player.replaceCurrentItem(with: nil)
    }

    // -------------------------------------------------------
//

//    var selectedRecording: OperationRecording?
//
//    var sortedRecordings: [OperationRecording] {
//        recordings.sorted { $0.createdAt > $1.createdAt }
//    }
//
//    var player: AVPlayer?
//    var temporaryVideoURL: URL?
//
//    /// Data를 임시 파일 URL로 만들고 AVPlayer를 생성
//    func prepareAndPlayVideo(for recording: OperationRecording) {
//        let fileManager = FileManager.default
//        let tempURL = fileManager.temporaryDirectory
//            .appendingPathComponent("\(recording.id).mp4")
//
//        do {
//            // videoData를 디스크에 임시 파일로 쓰기
//            try recording.videoData.write(to: tempURL, options: .atomic)
//
//            let player = AVPlayer(url: tempURL)
//            self.player = player
//            temporaryVideoURL = tempURL // 정리(cleanup)를 위해 URL 저장
//            player.play()
//
//        } catch {
//            print("Error writing temporary video file: \(error.localizedDescription)")
//        }
//    }
//
//    /// 플레이어를 중지하고 임시 파일을 삭제
//    func cleanupTemporaryFile() {
//        player?.pause()
//        player = nil
//
//        if let url = temporaryVideoURL {
//            do {
//                try FileManager.default.removeItem(at: url)
//                print("Cleaned up temporary file: \(url.path)")
//            } catch {
//                print("Error cleaning up temporary file: \(error.localizedDescription)")
//            }
//            temporaryVideoURL = nil
//        }
//    }
}

/// An extension of the player model to respond to experience controller transition events.
extension RecordingViewModel: AVExperienceController.Delegate {
    func experienceController(_ controller: AVExperienceController, prepareForTransitionUsing context: AVExperienceController.TransitionContext) async {
        /// Closing the player window transitions the player to its default `.embedded` experience.
        if context.toExperience == .embedded {
            // When exiting the player, stop playback and reset the model state.
            resetState()
        }
        /// Selecting a video on the main UI transitions the player to an `.expanded` experience.
        else if context.toExperience == .expanded {
            /// Configure placement when transitioning to an `.expanded` experience.
            if let scene {
                controller.configuration.placement = .over(scene: scene)
            } else {
                controller.configuration.placement = .unspecified
            }

            /// Set to `.none` to prevent automatically transitioning into an immersive experience.
            controller.configuration.expanded.automaticTransitionToImmersive = .default
        }
    }

    func experienceController(_: AVExperienceController, didChangeTransitionContext _: AVExperienceController.TransitionContext) {
        // Perform any necessary tasks after performing a transition.
    }

    func experienceController(_ controller: AVExperienceController, didChangeAvailableExperiences availableExperiences: AVExperienceController.Experiences) {
        // Add the immersive experience if it just became available.
        if !controller.allowedExperiences.contains(.immersive), availableExperiences.contains(.immersive) {
            controller.allowedExperiences = .recommended(including: [.immersive])
        }
    }
}
