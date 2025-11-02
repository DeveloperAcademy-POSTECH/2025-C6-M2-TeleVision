//
//  AssetListView.swift
//  Hippo
//
//  Created by yunsly on 10/30/25.
//

import SwiftUI

struct AssetListView: View {
    @Binding var isPresented: Bool
    
    @State private var selectedURL: URL?
    let operation: OperationDisplayModel

    var onCreateEntity: (URL) -> Void

    private var fileURLs: [URL] {
        operation.assets.map { $0.fileURL }
    }
    
    
    var body: some View {
        if isPresented {
            VStack {
                HStack {
                    Text("3D Asset List")
                        .font(.title)
                    Spacer()
                }
                .padding()
                .padding(.leading, 10)
                
                Spacer()
                
                AssetListScrollView(
                    fileURLs: fileURLs,
                    selectedURL: $selectedURL
                )
                Spacer()
                
                GlowingCapsuleButton(buttonText: "생성하기", action: {
                    if let url = selectedURL {
                        onCreateEntity(url)
                    }
                })
                .disabled(selectedURL == nil)
                .padding(.bottom, 20)
            }
            .frame(width: 680, height: 440)
            .padding()
            .glassBackgroundEffect()
            .onAppear {
                if selectedURL == nil {
                    selectedURL = fileURLs.first
                }
            }
            
        }
    }
}

#Preview {
    AssetListView(
        isPresented: .constant(true),
        operation: OperationDisplayModel.MockData,
        onCreateEntity: { entityID in
            print("Creating entity: \(entityID)")
        }
    )
}
