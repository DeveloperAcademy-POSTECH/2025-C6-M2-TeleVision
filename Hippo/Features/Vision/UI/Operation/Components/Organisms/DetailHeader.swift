//
//  DetailHeader.swift
//  HippoVision
//
//  Created by 김현기 on 10/21/25.
//

import SwiftUI

struct DetailHeader: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var appModel
    @Environment(OperationViewModel.self) private var viewModel
    let operation: OperationDisplayModel

    var body: some View {
        HStack {
            OperationStatusBadge(status: operation.status)

            Spacer()

            HStack(spacing: 16) {
                Button {} label: {
                    Image(systemName: "video")
                        .foregroundStyle(.primary)
                }
                .frame(width: 44, height: 44)
                .contentShape(.circle)
                .glassBackgroundEffect()
                .help(operation.assets.isEmpty ? "No Video" : "Video")

                Menu {
                    Button("수술 완료") {
                        Task {
                            await viewModel.updateOperationStatus(to: .completed)
                            appModel.refreshUI()
                        }
                    }
                    Button("수술 편집") {
                        viewModel.isShowingEditInputView = true
                    }
                    Button("수술 삭제", role: .destructive) {
                        Task {
                            await viewModel.deleteOperation()
                            appModel.refreshUI()
                            dismiss()
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.primary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
                .glassBackgroundEffect()
                .help("More")
            }
        }

        Divider()
    }
}

#Preview {
    DetailHeader(operation: OperationDisplayModel.MockData)
}
