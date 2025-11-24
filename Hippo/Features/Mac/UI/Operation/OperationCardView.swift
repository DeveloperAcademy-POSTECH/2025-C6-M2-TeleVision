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
                .buttonStyle(.plain)
                .padding(.horizontal)
                .background(.clear)
                .foregroundColor(.hippoGray500)
                .fontWeight(.semibold)
                

                VStack(alignment: .leading) {
                    Text(operation.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.hippoPrimary)
                        .padding(.bottom, 2)
                    Text(operation.operationDate.toOperationDateString())
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.hippoGray500)
                }

                Spacer()

                HStack {
                    Button {
                        //수술 수정
                        onEdit(operation.id)
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.title2)
                            .padding(12)
                            .foregroundColor(.hippoGray500)
                    }
                    .buttonStyle(.plain)

                    Button {
                        //수술 삭제
                        onDelete(operation.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.title2)
                            .padding(12)
                            .foregroundColor(.hippoGray500)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        //녹화 리스트 UI
                    } label: {
                        Image(systemName: "video")
                            .font(.title2)
                            .padding(12)
                            .foregroundColor(.hippoGray500)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !isCardCollapsed {
                Divider()

                //환자정보/집도의/수술부위/진단(병명)
                HStack {
                    if let name = operation.name,
                        let gender = operation.gender {
                        VStack(alignment: .leading) {
                            Text("환자 정보")
                                .padding(.vertical, 4)
                                .font(.callout)
                                .foregroundColor(.hippoGray500)
                            HStack {
                                Text(name)
                                Text("/")
                                Text(gender)
                                Text("/")
                                Text(operation.age)
                            }
                            .font(.headline)
                            .foregroundColor(.hippoGray700)
                        }
                        
                        Spacer()
                    }
                    
                    VStack(alignment: .leading) {
                        Text("집도의")
                            .padding(.vertical, 4)
                            .font(.callout)
                            .foregroundColor(.hippoGray500)
                        Text(operation.surgeon)
                            .font(.headline)
                            .foregroundColor(.hippoGray700)
                    }

                    Spacer()

                    VStack(alignment: .leading) {
                        Text("수술부위")
                            .padding(.vertical, 4)
                            .font(.callout)
                            .foregroundColor(.hippoGray500)
                        Text(operation.surgicalSite)
                            .font(.headline)
                            .foregroundColor(.hippoGray700)
                    }

                    Spacer()

                    VStack(alignment: .leading) {
                        Text("진단(병명)")
                            .padding(.vertical, 4)
                            .font(.callout)
                            .foregroundColor(.hippoGray500)
                        Text(operation.diagnosis)
                            .font(.headline)
                            .foregroundColor(.hippoGray700)
                    }

                    Spacer()
                }
                .padding(.bottom, 4)

                Divider()

                //상세 내용
                VStack(alignment: .leading) {
                    Text("세부 내용")
                        .padding(.vertical, 4)
                        .font(.callout)
                        .foregroundColor(.hippoGray500)
                    Text(operation.details)
                        .font(.headline)
                        .foregroundColor(.hippoGray700)
                }
                .padding(.bottom, 4)

                Divider()

                VStack(alignment: .leading) {
                    Text("3D 모델")
                        .padding(.vertical, 4)
                        .font(.callout)
                        .foregroundColor(.hippoGray500)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(operation.assets) { asset in
                                AssetThumbnailView(
                                    url: asset.fileURL,
                                    fileName: asset.fileName,
                                    enableHoverDimming: false
                                )
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
                .fill(.white)
        )
    }
}
