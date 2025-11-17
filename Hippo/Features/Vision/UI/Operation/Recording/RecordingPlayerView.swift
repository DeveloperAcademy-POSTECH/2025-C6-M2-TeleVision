//
//  RecordingPlayerView.swift
//  Hippo
//
//  Created by 김현기 on 11/17/25.
//

import AVFoundation
import SwiftUI

struct RecordingPlayerView: View {
    let spacing = 20.0

    @Environment(AppModel.self) private var appModel
    @Environment(SceneProvider.self) private var sceneProvider
    @State private var viewModel = RecordingViewModel()

    init(recordings: [OperationRecording]) {
        viewModel.recordings = recordings
    }

    var body: some View {
        ScrollView([.horizontal]) {
            HStack(spacing: spacing) {
                ForEach(viewModel.recordings) { recording in
                    RecordCard(record: recording)
                }
            }
        }
        .padding(spacing)
        .scrollIndicators(.hidden)
        .environment(viewModel)
        .onChange(of: sceneProvider.scene, initial: true) { _, newScene in
            // Update the player model with the new scene.
            viewModel.scene = newScene
        }
    }
}
