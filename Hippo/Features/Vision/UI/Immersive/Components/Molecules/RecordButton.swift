//
//  RecordButton.swift
//  Hippo
//
//  Created by 김현기 on 10/26/25.
//

import SwiftUI

struct RecordButton: View {
    @Environment(ImmersiveViewModel.self) private var viewModel
    @Environment(OperationViewModel.self) private var operationViewModel
    @State private var manager = RecordingManager()

    var body: some View {
        Button(action: manager.toggleRecording) {
            HStack {
                Text("녹화")
                    .font(.callout)
                Spacer()

                if manager.isRecording {
                    Text(manager.formattedElapsedTime)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.trailing, 2)
                }

                RecordingIndicator(isRecording: manager.isRecording)
            }
            .padding(.horizontal, 10)
            .frame(maxHeight: .infinity)
        }
        .contentShape(.capsule)
        .frame(width: manager.isRecording ? 150 : 100, height: 44)
        .buttonStyle(.plain)
        .glassBackgroundEffect(in: .capsule, displayMode: .always)
        .background(.clear)
        .overlay {
            Capsule()
                .stroke(manager.isRecording ? Color.red.opacity(0.5) : .white.opacity(0.5), lineWidth: 1)
        }
        .shadow(color: manager.isRecording ? .red.opacity(0.5) : .black.opacity(0.5), radius: 10, x: 2, y: 2)
        .animation(.smooth(duration: 0.5), value: manager.isRecording)
        .task {
            manager.onRecordingFinished = { tempURL in
                Task {
                    await manager.addRecordingToOperation(
                        operationID: operationViewModel.state.operation!.id,
                        patientID: operationViewModel.state.patient!.id,
                        tempURL: tempURL
                    )
                }
            }
        }
        .onChange(of: manager.isRecording) {
            manager.isRecordingStateChanged()
        }
        .onDisappear {
            manager.setTimerReset()
        }
    }
}

#Preview {
    RecordButton()
}
