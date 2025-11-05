//
//  OperationInputView.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/4/25.
//

import SwiftUI

struct OperationInputView: View {
    @Binding var isOperationInputSheetPresented: Bool
    @State private var operationDate = Date()

    var body: some View {
        Section(header: Text("수술 추가하기")) {
            
            //텍스트필드 영역
            Form {
                TextField("수술 타이틀", text: .constant(""))
                HStack {
                    DatePicker("수술날짜", selection: $operationDate)
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                }
                TextField("집도의 성명", text: .constant(""))
                TextField("수술부위", text: .constant(""))
                TextField("진단(병명)", text: .constant(""))
                TextField("수술상세", text: .constant(""), axis: .vertical)
                    .lineLimit(5...10)
            }
            
            //3D 모델링 추가 뷰
            HStack {
                Text("3D 모델링 파일")

                Spacer()
                Button {
                    //TODO: 3D 모델 추가 UI 구현?
                } label: {
                    Image(systemName: "plus")
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    //TODO: 3D 모델 파일로 UI 테스트 필요
                    ForEach(0..<10) { index in
                        Rectangle()
                            .frame(width: 50, height: 50)
                    }
                }
                .padding(.vertical)
            }
        }
        .padding()

        //취소/저장 버튼
        HStack {
            Button("취소") {
                isOperationInputSheetPresented = false
            }
            Button("저장") {
                isOperationInputSheetPresented = false
            }
        }
        .padding()
    }
}

#Preview {
    RootView()
}
