//
//  OperationCardView.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/5/25.
//

import SwiftUI

struct OperationCardView: View {
    @State var isCardCollapsed: Bool = false

    let operation: OperationCardDisplayModel
    
    let onEdit: (String) -> Void
    let onDelete: (String) -> Void

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
                    Text("\(operation.operationDate)")
                }

                Spacer()

                HStack {
                    Button {
                        //TODO: 수술 수정
//                        onEdit()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    Button {
                        //TODO: 수술 삭제
                        onDelete(operation.id)
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
                    
                    if let name = operation.name,
                        let gender = operation.gender {
                        VStack(alignment: .leading) {
                            Text("Patient Info")
                                .padding(.vertical, 4)
                            HStack {
                                Text(name)
                                Text("/")
                                Text(gender)
                                Text("/")
                                Text(operation.age)
                            }
                        }
                        
                        Spacer()
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Surgeon")
                            .padding(.vertical, 4)
                        Text(operation.surgeon)
                    }

                    Spacer()

                    VStack(alignment: .leading) {
                        Text("Surgical Site")
                            .padding(.vertical, 4)
                        Text(operation.surgicalSite)
                    }

                    Spacer()

                    VStack(alignment: .leading) {
                        Text("Diagnosis")
                            .padding(.vertical, 4)
                        Text(operation.diagnosis)
                    }

                    Spacer()
                }

                Divider()

                //상세 내용
                VStack(alignment: .leading) {
                    Text("Details")
                        .padding(.vertical, 4)
                    Text(operation.details)
                }

                Divider()

                VStack(alignment: .leading) {
                    Text("3D models")
                        .padding(.vertical, 4)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            //TODO: 3D 모델 파일로 UI 테스트 필요
                            //TODO: 마우스 호버 시, 배경 Dim처리 + 삭제 버튼 활성화
                            ForEach(operation.assets) { asset in
                                // 썸네일을 준비하지 않았다면 파일명만 먼저
                                Text(asset.fileName)
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
