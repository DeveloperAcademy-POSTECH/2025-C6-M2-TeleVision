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
    let onSave: () async -> Void

    var body: some View {
        Section(header: Text("Add Operation")) {

            //텍스트필드 영역
            Form {
                TextField("Title", text: $state.title)
                HStack {
                    DatePicker(
                        "Operation Date",
                        selection: $state.operationDate
                    )
                    .environment(\.locale, Locale(identifier: "ko_KR"))
                }
                TextField("Surgeon", text: $state.surgeon)
                TextField("Surgical Site", text: $state.surgicalSite)
                TextField("Diagnosis", text: $state.diagnosis)
                TextField("Details", text: $state.details, axis: .vertical)
                    .lineLimit(5...10)
            }

            //3D 모델링 추가 뷰
            HStack {
                Text("3D Models")

                Spacer()

                Button {
                    let selections = state.pickAssets()
                    for (url, fileName) in selections {
                        state.addAsset(fileURL: url, fileName: fileName)  // 한 번에 하나씩 추가
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    //TODO: 3D 모델 파일로 UI 테스트 필요
                    //TODO: 마우스 호버 시, 배경 Dim처리 + 삭제 버튼 활성화
                    ForEach(state.assets) { asset in
                        // 썸네일을 준비하지 않았다면 파일명만 먼저
                        Text(asset.fileName)
                    }
                }
                .padding(.vertical)
            }
        }
        .padding()

        //취소/저장 버튼
        HStack {
            Button("Cancel") {
                isPresentingOperationInput = false
            }
            Button("Save") {
                Task {
                    await onSave()
                }
                isPresentingOperationInput = false
            }
        }
        .padding()
    }

}

#Preview {
    @Previewable @State var state = OperationInputState()
    OperationInputView(
        isPresentingOperationInput: .constant(true),
        state: $state,
        onSave: {}
    )
}
