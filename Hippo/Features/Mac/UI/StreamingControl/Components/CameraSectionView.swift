//
//  CameraSectionView.swift
//  HippoMac
//
//  Camera input section component
//

import SwiftUI
import AVFoundation

struct CameraSectionView: View {
    @Binding var cameraInputMode: CameraInputMode
    @Binding var selectedLeftDevice: AVCaptureDevice?
    @Binding var selectedRightDevice: AVCaptureDevice?
    @Binding var selectedSingleDevice: AVCaptureDevice?
    let availableDevices: [AVCaptureDevice]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center) {
                Text("Camera Input")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.black)
                Spacer()
                CameraInputToggle(selectedMode: $cameraInputMode)
            }

            cameraPickers
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
    }

    @ViewBuilder
    private var cameraPickers: some View {
        if cameraInputMode == .dual {
            // Dual: Left & Right Camera
            HStack(spacing: 40) {
                CameraPickerRow(
                    label: "Left Camera",
                    selection: $selectedLeftDevice,
                    availableDevices: availableDevices
                )
                CameraPickerRow(
                    label: "Right Camera",
                    selection: $selectedRightDevice,
                    availableDevices: availableDevices
                )
            }
        } else {
            // Single: One Camera
            HStack(spacing: 16) {
                CameraPickerRow(
                    label: "Camera",
                    selection: $selectedSingleDevice,
                    availableDevices: availableDevices
                )
                Spacer()
            }
        }
    }
}
