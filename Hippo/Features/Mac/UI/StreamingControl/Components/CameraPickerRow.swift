//
//  CameraPickerRow.swift
//  HippoMac
//
//  Camera picker row component
//

import SwiftUI
import AVFoundation

struct CameraPickerRow: View {
    let label: String
    @Binding var selection: AVCaptureDevice?
    let availableDevices: [AVCaptureDevice]

    var body: some View {
        HStack(spacing: 16) {
            Text(label)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.gray)
                .frame(width: 120, alignment: .leading)

            if availableDevices.isEmpty {
                Text("No camera detected")
                    .foregroundColor(.gray)
                    .frame(minWidth: 280, alignment: .leading)
            } else {
                Picker("", selection: $selection) {
                    Text("Select a camera").tag(nil as AVCaptureDevice?)
                    ForEach(availableDevices, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(Optional(device))
                    }
                }
                .labelsHidden()
                .frame(minWidth: 280)
            }
        }
    }
}
