//
//  LogoHeader.swift
//  HippoVision
//
//  Created by 김현기 on 10/21/25.
//

import SwiftUI

/// 앱 로고 헤더
struct LogoHeader: View {
    var body: some View {
        HStack {
            Image("HippoLogo")
                .resizable()
                .frame(width: 40, height: 40)
                .scaledToFit()
                .padding(.trailing, 8)
            
            Text("Hippo")
                .foregroundStyle(.primary)
                .font(.extraLargeTitle2)

            Spacer()
        }
    }
}

#Preview {
    LogoHeader()
}
