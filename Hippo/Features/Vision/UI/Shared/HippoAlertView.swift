//
//  HippoAlertView.swift
//  Hippo
//
//  Created by 김현기 on 10/27/25.
//

import SwiftUI

struct HippoAlertView: View {
    @Binding var isPresented: Bool
    let onConfirm: () -> Void

    var systemName: String = "iphone.and.arrow.forward.outward"
    var title: String = "나가시겠습니까?"
    var content: String = "나가도 다시 들어올 수 있지만, 현재 상태가 초기화될 수 있습니다."

    var body: some View {
        if isPresented {
            VStack(spacing: 0) {
                // 아이콘
                Image(systemName: systemName)
                    .font(.system(size: 48))
                    .foregroundStyle(.hippoPrimary)
                    .padding(.vertical, 32)

                // 제목
                Text(title)
                    .font(.largeTitle)
                    .foregroundStyle(.primary)
                    .padding(.bottom, 24)

                // 설명
                Text(content)
                    .font(.title)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 32)

                // 구분선
                Divider().padding(.bottom, 12)

                // 네 버튼
                Button {
                    onConfirm()
                    isPresented = false
                } label: {
                    Text("네")
                        .font(.title)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(.borderless)

                Spacer().frame(height: 12)

                // 아니오 버튼
                Button {
                    isPresented = false
                } label: {
                    Text("아니오")
                        .font(.title)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(.borderless)
            }
            .padding(32)
            .frame(width: 500)
            .glassBackgroundEffect()
        }
    }
}

extension HippoAlertView {
    func systemName(_ systemName: String) -> Self {
        var view = self
        view.systemName = systemName
        return view
    }

    func title(_ title: String) -> Self {
        var view = self
        view.title = title
        return view
    }

    func content(_ message: String) -> Self {
        var view = self
        view.content = message
        return view
    }
}
