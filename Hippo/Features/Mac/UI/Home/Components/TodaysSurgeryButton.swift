//
//  TodaysSurgeryButton.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/13/25.
//

import SwiftUI

struct TodaysSurgeryButton: View {
    @Binding var rootVM: MacRootViewModel

    var body: some View {
        Button {
            rootVM.selectTodaysSurgery()
        } label: {
            HStack {
                Text("오늘의 수술")

                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .font(.title3)
            .fontWeight(.bold)
            .foregroundColor(rootVM.isTodaysSurgerySelected ? .white : .hippoGray500)
            .background(RoundedRectangle(cornerRadius: 8).fill(rootVM.isTodaysSurgerySelected ? .hippoPrimary : .white))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RootView()
}
