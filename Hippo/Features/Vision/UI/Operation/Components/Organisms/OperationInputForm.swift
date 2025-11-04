//
//  OperationInputForm.swift
//  Hippo
//
//  Created by 김현기 on 10/30/25.
//

import RealityKit
import SwiftUI
internal import UniformTypeIdentifiers

struct OperationInputForm: View {
    @Binding var title: String
    @Binding var diagnosis: String
    @Binding var surgeon: String
    @Binding var operationDate: Date
    @Binding var detail: String
    @Binding var selectedAssets: [OperationAsset]

    @Binding var isShowingFilePicker: Bool

    var body: some View {
        VStack(spacing: 28) {
            FormSection {
                TextField("수술명을 입력해주세요", text: $title)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(.thinMaterial)
                    .cornerRadius(12)
            }
            .title("수술명")

            FormSection {
                TextField("진단(병명)을 입력해주세요", text: $diagnosis)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(.thinMaterial)
                    .cornerRadius(12)
            }
            .title("진단(병명)")

            FormSection {
                TextField("이름을 입력해주세요", text: $surgeon)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(.thinMaterial)
                    .cornerRadius(12)
            }
            .title("집도의")

            FormSection {
                HStack {
                    DatePicker(
                        "",
                        selection: $operationDate,
                        displayedComponents: .date
                    )
                    .labelsHidden()

                    Spacer().frame(width: 12)

                    DatePicker(
                        "",
                        selection: $operationDate,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()

                    Spacer()
                }
            }
            .title("수술 날짜 / 시간")

            FormSection {
                TextField("특이사항을 작성해주세요", text: $detail, axis: .vertical)
                    .lineLimit(5 ... 10)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(.thinMaterial)
                    .cornerRadius(12)
            }
            .title("상세 내용")

            FileAttachmentSection(
                selectedAssets: $selectedAssets,
                isShowingFilePicker: $isShowingFilePicker
            )
        }
    }
}
