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
                    alignment: .leading,
                    horizontalSpacing: 24,
                    verticalSpacing: 16
                ) {
                    GridRow {
                        Text("Title")
                        TextField("", text: $state.title)
                    }

                    GridRow {
                        Text("Operation Date")
                        HStack {
                            DatePicker(
                                "",
                                selection: $state.operationDate
                            )
                            .environment(\.locale, Locale(identifier: "ko_KR"))
                        }
                    }

                    GridRow {
                        Text("Surgeon")
                        TextField("", text: $state.surgeon)
                    }

                    GridRow {
                        Text("Surgical site")
                        TextField("", text: $state.surgicalSite)
                    }

                    GridRow {
                        Text("Diagnosis")
                        TextField("", text: $state.diagnosis)
                    }

                    GridRow {
                        Text("Details")
                        TextField("", text: $state.details, axis: .vertical)
                            .lineLimit(5...10)
                    }
                }
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundColor(.hippoGray900)

                //3D 모델링 추가 뷰
                HStack(alignment: .top) {
                    Text("3D Models")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.hippoGray900)

                    Spacer()

                    Button {
                        let selections = state.pickAssets()
                        for (url, fileName) in selections {
                            state.addAsset(fileURL: url, fileName: fileName)  // 한 번에 하나씩 추가
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

                //에셋 횡스크롤 뷰
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
                    .padding(.vertical)
                }
            } header: {
                HStack {
                    Text("Add Operation")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.hippoGray500)
                    Spacer()
                }
            }

            Divider()

            //취소/저장 버튼
            HStack {
                Spacer()

                Button {
                    isPresentingOperationInput = false
                } label: {
                    Text("Cancel")
                        .font(.callout)
                        .padding(12)
                }
                .background(.hippoBackground)
                .foregroundColor(.hippoGray500)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .buttonStyle(.plain)

                Button {
                    if mode == .create {
                        print("operation created")
                    } else {
                        print("operation edited")
                    }

                    Task {
                        await onSave()
                    }
                    isPresentingOperationInput = false
                } label: {
                    Text("Save")
                        .font(.callout)
                        .padding(12)
                }
                .background(.hippoPrimary)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
}

#Preview {
    RootView()
}
