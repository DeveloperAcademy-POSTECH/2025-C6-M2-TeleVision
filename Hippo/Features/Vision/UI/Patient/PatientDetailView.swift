//
//  PatientDetailView.swift
//  HippoVision
//
//  Created by 김현기 on 10/27/25.
//

import SwiftUI

struct PatientDetailView: View {
    @State private var viewModel = PatientViewModel()
    
    let patientId: String

    var body: some View {
        VStack {
            
        }
        .task {
            await viewModel.load(patientID: patientId)
        }
    }
}

#Preview {
    PatientDetailView(patientId: "12345678")
}
