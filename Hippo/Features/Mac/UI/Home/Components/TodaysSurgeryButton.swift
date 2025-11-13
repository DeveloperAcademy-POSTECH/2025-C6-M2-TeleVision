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
                Text("Today's Surgery")

                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .font(.title3)
            .fontWeight(.bold)
            .foregroundColor(rootVM.isTodaysSurgerySelected ? .white : .hippoGray)
            .background(RoundedRectangle(cornerRadius: 8).fill(rootVM.isTodaysSurgerySelected ? .hippoPrimary : .white))
        }
        .buttonStyle(.plain)
        .listRowInsets(.init(top: 0, leading: 4, bottom: 0, trailing: 4))
    }
}

#Preview {
   RootView()
}
