//
//  FinishSurgeryAlertView.swift
//  Hippo
//
//  Created by 김현기 on 10/27/25.
//

import SwiftUI

struct FinishSurgeryAlertView: View {
    @Binding var isPresented: Bool
    let onConfirm: () -> Void

    var body: some View {
        if isPresented {
            VStack(spacing: 0) {
                // 아이콘
                Image(systemName: "iphone.and.arrow.forward.outward")
                    .font(.system(size: 48))
                    .foregroundStyle(.hippoPrimary)
                    .padding(.vertical, 32)

                // 제목
                Text("나가시겠습니까?")
                    .font(.largeTitle)
                    .foregroundStyle(.primary)
                    .padding(.bottom, 24)

                // 설명
                Text("나가도 다시 들어올 수 있지만, 현재 상태가 초기화될 수 있습니다.")
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
