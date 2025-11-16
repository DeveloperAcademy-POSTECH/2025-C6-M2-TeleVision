//
//  RecordingPlayerView.swift
//  Hippo
//
//  Created by 김현기 on 11/17/25.
//

import AVFoundation
import SwiftUI

struct RecordingPlayerView: View {
    let recordings: [OperationRecording]

    @State private var selectedRecording: OperationRecording?

    private var sortedRecordings: [OperationRecording] {
        recordings.sorted { $0.createdAt > $1.createdAt }
    }

    init(recordings: [OperationRecording]) {
        self.recordings = recordings

        _selectedRecording = State(initialValue: recordings.sorted { $0.createdAt > $1.createdAt }.first)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 1. 메인 플레이어 영역
            ZStack {
                if let selectedRecording {
                    // 선택된 Recording을 MainVideoPlayerView에 전달
                    MainVideoPlayerView(recording: selectedRecording)
                } else {
                    // 비디오가 없는 경우
                    Color.black
                    Text("No Recordings Available")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxHeight: .infinity) // 상단 영역 최대화

            // 2. 하단 썸네일 캐로셀 영역
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(sortedRecordings) { recording in
                        ThumbnailVideoView(
                            recording: recording,
                            isSelected: recording.id == selectedRecording?.id
                        )
                        .onTapGesture {
                            // 썸네일 클릭 시 selectedRecording 상태 업데이트
                            selectedRecording = recording
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 120) // 하단 캐로셀 높이 고정
            .background(.thinMaterial)
        }
        .background(.black)
    }
}
