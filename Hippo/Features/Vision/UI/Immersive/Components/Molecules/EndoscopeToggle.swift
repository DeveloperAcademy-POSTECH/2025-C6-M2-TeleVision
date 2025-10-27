//
//  EndoscopeToggle.swift
//  Hippo
//
//  Created by 김현기 on 10/26/25.
//

import SwiftUI

struct EndoscopeToggle: View {
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle("내시경", isOn: $isOn)
            .toggleStyle(.switch)
            .tint(.hippoPrimary)
            .font(.headline)
            .foregroundStyle(.secondary)
            .frame(width: 130, height: 40)
    }
}

#Preview {
    EndoscopeToggle(isOn: .constant(true))
}
