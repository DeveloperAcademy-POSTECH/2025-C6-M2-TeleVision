//
//  OperationInputView.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/4/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct OperationInputView: View {
    @Binding var isPresentingOperationInput: Bool

    // ViewModel State 바인딩 (HomeView의 rootVM에서 전달받음)
    @Binding var state: OperationInputState
    let mode: OperationInputMode

    let onSave: () async -> Void

    var body: some View {
        VStack {
            Section {
                Grid(
                    alignment: .leadingFirstTextBaseline,
                    horizontalSpacing: 24,
                    verticalSpacing: 16
                ) {
                    GridRow {
                        Text("수술명")
                        TextField("", text: $state.title)
                    }

                    GridRow {
                        Text("수술일시")
                        DatePicker(
                            "",
                            selection: $state.operationDate
                        )
                        .datePickerStyle(.stepperField)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                    }

                    GridRow {
                        Text("집도의")
                        TextField("", text: $state.surgeon)
                    }

                    GridRow {
                        Text("수술부위")
                        TextField("", text: $state.surgicalSite)
                    }

                    GridRow {
                        Text("진단(병명)")
                        TextField("", text: $state.diagnosis)
                    }

                    GridRow {
                        Text("세부내용")
                        TextField("", text: $state.details, axis: .vertical)
                            .lineLimit(5 ... 10)
                    }
                }
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundColor(.hippoGray900)

                // 3D 모델링 추가 뷰
                HStack(alignment: .top) {
                    Text("3D 모델링 파일")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.hippoGray900)

                    Spacer()

                    Button {
                        let selections = state.pickAssets()
                        for (url, fileName) in selections {
                            state.addAsset(fileURL: url, fileName: fileName) // 한 번에 하나씩 추가
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.hippoGray500)
                            .background(
                                Circle()
                                    .fill(Color.hippoBackground) // 혹은 .hippoPrimary
                                    .frame(width: 32, height: 32)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding()
                }

                // 에셋 횡스크롤 뷰
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(state.assets) { asset in
                            Button {
                                state.removeAsset(id: asset.id)
                            } label: {
                                AssetThumbnailView(
                                    url: asset.fileURL,
                                    fileName: asset.fileName,
                                    onDelete: { state.removeAsset(id: asset.id) },
                                    enableHoverDimming: true
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom)
                }
            } header: {
                HStack {
                    Text("수술 추가")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.hippoGray500)
                    Spacer()
                }
                .padding(.bottom, 8)
            }

            Divider()

            // 취소/저장 버튼
            HStack {
                Spacer()

                Button {
                    isPresentingOperationInput = false
                } label: {
                    Text("취소")
                        .font(.callout)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 8)
                        .background(.hippoBackground)
                        .foregroundColor(.hippoGray500)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        await onSave()
                    }
                    isPresentingOperationInput = false
                } label: {
                    Text("저장")
                        .font(.callout)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 8)
                        .background(.hippoPrimary)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
}

#Preview {
    RootView()
}
