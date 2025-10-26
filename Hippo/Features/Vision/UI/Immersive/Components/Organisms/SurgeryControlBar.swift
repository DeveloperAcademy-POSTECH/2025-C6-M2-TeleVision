//
//  SurgeryControlBar.swift
//  Hippo
//
//  Created by 김현기 on 10/27/25.
//

import SwiftUI

struct SurgeryControlBar: View {
    @Binding var isEndoscopicActive: Bool
    let onOpenEntityPanel: () -> Void
    let onRecord: () -> Void
    let onFinishSurgery: () -> Void

    var body: some View {
        HStack {
            CircleIconButton(
                systemName: "iphone.and.arrow.forward.outward",
                action: onFinishSurgery
            )
            .padding(24)

            HStack {
                EndoscopeToggle(isOn: $isEndoscopicActive)
                    .padding(40)

                Spacer()

                GlowingCircleButton(
                    imageName: "AddEntityIcon",
                    action: onOpenEntityPanel
                )
                .padding(24)

                Spacer()

                RecordButton(action: onRecord)
                    .padding(40)
            }
            .frame(width: 720, height: 120)
            .glassBackgroundEffect(in: .capsule, displayMode: .always)

            Circle()
                .fill(.clear)
                .frame(width: 80, height: 80)
                .padding(24)
        }
    }
}

#Preview {
    SurgeryControlBar(
        isEndoscopicActive: .constant(false),
        onOpenEntityPanel: {},
        onRecord: {},
        onFinishSurgery: {}
    )
    .padding()
}
