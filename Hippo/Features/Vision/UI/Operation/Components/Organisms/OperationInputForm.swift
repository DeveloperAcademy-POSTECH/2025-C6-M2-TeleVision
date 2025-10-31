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
    @Binding var selected3DFiles: [URL]

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

            FormSection {
                // TODO: 3D 모델 추가 컴포넌트

                HStack {
                    if selected3DFiles.isEmpty {
                        HStack {
                            Spacer()

                            Image(systemName: "cube.transparent")
                                .font(.title2)
                                .foregroundStyle(.secondary)

                            Text("USDZ 파일을 첨부해주세요")
                                .font(.body)
                                .foregroundStyle(.secondary)

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 150)
                    }
                    //
                    else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                Spacer().frame(width: 12)
                                ForEach(selected3DFiles, id: \.self) { url in
                                    ZStack(alignment: .center) {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.hippoBlack)
                                            .frame(width: 130, height: 130)
                                            

                                        Model3D(url: url) { model in
                                            model
                                                .resizable()
                                                .scaledToFit()

                                        } placeholder: { ProgressView() }
                                            .frame(width: 110, height: 110)
                                            .onAppear { let _ = url.startAccessingSecurityScopedResource() }
                                            .onDisappear { url.stopAccessingSecurityScopedResource() }
                                    }
                                    .padding(.trailing, 12)
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: 150)
                .background(.thinMaterial)
                .cornerRadius(12)
                .fileImporter(
                    isPresented: $isShowingFilePicker,
                    allowedContentTypes: [.usd, .usdz],
                    allowsMultipleSelection: true
                ) { result in
                    switch result {
                    case let .success(urls):
                        selected3DFiles.append(contentsOf: urls)
                        print("File import succeeded: \(urls)")

                    case let .failure(error):
                        print("File import failed: \(error.localizedDescription)")
                    }
                }
            }
            .title("3D 모델 파일")
            .addAction { isShowingFilePicker = true }
        }
    }

//    func handleFile(url: URL) {
//        // 💡 시니어의 조언:
//        // 이 URL은 앱이 즉시 접근할 수 있지만,
//        // 나중에 다시 접근하려면 '보안 범위 접근'을 시작해야 함.
//
//        let shouldAccess = url.startAccessingSecurityScopedResource()
//
//        if shouldAccess {
//            defer {
//                // 파일 작업이 끝나면 반드시 접근을 중지해야 함
//                url.stopAccessingSecurityScopedResource()
//            }
//
//            // 파일 데이터를 읽는 로직 (예: Data로 읽기)
//            do {
//                let fileData = try Data(contentsOf: url)
//                print("파일 데이터 로드 성공: \(fileData.count) bytes")
//
//                selected3DFiles.append(fileData)
//            } catch {
//                print("파일 읽기 실패: \(error.localizedDescription)")
//            }
//
//        } else {
//            print("보안 리소스 접근 실패")
//        }
//    }
}
