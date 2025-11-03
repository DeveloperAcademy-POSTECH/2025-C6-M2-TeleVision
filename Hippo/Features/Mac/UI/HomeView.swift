//
//  HomView.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/2/25.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationSplitView {
            List {
                Section(header: Text("Today's Surgery")) {
                    Text("오늘의 수술 비어있음")
                }
                Section(header: Text("Patient List")) {
                    Text("환자 리스트 비어있음")
                }
            }
        } detail: {
            //TODO: PatientDetailView()
            Text("환자 디테일 비어있음")
        }
    }
}

#Preview {
    HomeView()
}
