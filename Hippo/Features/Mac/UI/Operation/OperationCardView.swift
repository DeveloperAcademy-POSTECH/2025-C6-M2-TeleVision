//
//  OperationCardView.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/5/25.
//

import SwiftUI

struct OperationCardView: View {
    @State var isCardCollapsed: Bool = false

    let operation: OperationDisplayModel

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button {
                    isCardCollapsed.toggle()
                } label: {
                    if !isCardCollapsed {
                        Image(systemName: "chevron.up")
                    } else {
                        Image(systemName: "chevron.down")
                    }

                }
                .padding(.horizontal)

                VStack(alignment: .leading) {
                    Text(operation.title)
                    Text(operation.dateText)
                }

                Spacer()

                HStack {
                    Button {
                        //TODO: 수술 수정
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    Button {
                        //TODO: 수술 삭제
                    } label: {
                        Image(systemName: "trash")
                    }
                    Button {
                        //TODO: 녹화 리스트 UI
                    } label: {
                        Image(systemName: "video")
                    }
                }
            }

            if !isCardCollapsed {
                Divider()

                //환자정보/집도의/수술부위/진단(병명)
                HStack {

                    VStack(alignment: .leading) {
                        Text("환자 정보")
                            .padding(.vertical, 4)
                        Text("이름 성별 / 나이")
                    }

                    Spacer()

                    VStack(alignment: .leading) {
                        Text("집도의")
                            .padding(.vertical, 4)
                        Text(operation.surgeon)
                    }

                    Spacer()

                    VStack(alignment: .leading) {
                        Text("수술 부위")
                            .padding(.vertical, 4)
                        Text("abd")
                    }

                    Spacer()

                    VStack(alignment: .leading) {
                        Text("진단(병명)")
                            .padding(.vertical, 4)
                        Text(operation.diagnosis)
                    }

                    Spacer()
                }

                Divider()

                //상세 내용
                VStack(alignment: .leading) {
                    Text("상세 내용")
                        .padding(.vertical, 4)
                    Text(operation.details)
                }

                Divider()

                VStack(alignment: .leading) {
                    Text("3D 모델 파일")
                        .padding(.vertical, 4)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            //TODO: 3D 모델 파일로 UI 테스트 필요
                            //TODO: 마우스 호버 시, 배경 Dim처리 + 삭제 버튼 활성화
                            ForEach(0..<10) { index in
                                Rectangle()
                                    .frame(width: 50, height: 50)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.gray.opacity(0.15))
        )
    }
}

//#Preview {
//    OperationCardView(operation: .sample)
//}
