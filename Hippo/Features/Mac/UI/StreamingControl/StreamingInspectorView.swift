//
//  StreamingMonitorPanel.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/4/25.
//

import SwiftUI

struct StreamingInspectorView: View {
    var body: some View {
        ScrollView {
            //Controls
            Section {
                
            } header: {
                HStack {
                    Text("Controls")
                    Spacer()
                }
                
            }
            
            //Statistics
            Section {
                
            } header: {
                HStack {
                    Text("Statistics")
                    Spacer()
                }
            }
        }
            .padding()
    }
}

#Preview {
    StreamingInspectorView()
}
