//
//  MainVideoPlayerView.swift
//  Hippo
//
//  Created by 김현기 on 11/17/25.
//

import AVKit
import SwiftUI

/// 선택된 영상(Data)을 받아 임시 파일로 변환하고 재생하는 뷰
/// BasicDataPlayerView의 로직을 기반으로 함
struct MainVideoPlayerView: View {
    let recording: OperationRecording

    @State private var player: AVPlayer?
    @State private var temporaryVideoURL: URL?

    var body: some View {
        VideoPlayer(player: player)
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                prepareAndPlayVideo(for: recording)
            }
            .onDisappear {
                cleanupTemporaryFile()
            }
            .onChange(of: recording.id) { _, _ in
                // 1. 현재 선택된 recording 객체를 찾는다. (이 뷰는 이미 새 recording을 받았음)
                let newRecording = recording

                // 2. 기존 플레이어와 임시 파일 정리
                cleanupTemporaryFile()

                // 3. 새 비디오로 플레이어 준비
                prepareAndPlayVideo(for: newRecording)
            }
    }

    /// Data를 임시 파일 URL로 만들고 AVPlayer를 생성
    private func prepareAndPlayVideo(for recording: OperationRecording) {
        let fileManager = FileManager.default
        let tempURL = fileManager.temporaryDirectory
            .appendingPathComponent("\(recording.id).mp4")

        do {
            // videoData를 디스크에 임시 파일로 쓰기
            try recording.videoData.write(to: tempURL, options: .atomic)

            let player = AVPlayer(url: tempURL)
            self.player = player
            temporaryVideoURL = tempURL // 정리(cleanup)를 위해 URL 저장
            player.play()

        } catch {
            print("Error writing temporary video file: \(error.localizedDescription)")
        }
    }

    /// 플레이어를 중지하고 임시 파일을 삭제
    private func cleanupTemporaryFile() {
        player?.pause()
        player = nil

        if let url = temporaryVideoURL {
            do {
                try FileManager.default.removeItem(at: url)
                print("Cleaned up temporary file: \(url.path)")
            } catch {
                print("Error cleaning up temporary file: \(error.localizedDescription)")
            }
            temporaryVideoURL = nil
        }
    }
}
