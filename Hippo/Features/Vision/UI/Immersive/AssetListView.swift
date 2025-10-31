//
//  AssetListView.swift
//  Hippo
//
//  Created by yunsly on 10/30/25.
//

import SwiftUI

struct AssetListView: View {
    @Binding var isPresented: Bool
    var onCreateEntity: (String) -> Void
    
    // TODO: Operation Context 연결해야 함
    private let selectedEntityID = "Sample1"
    
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
                
                // TODO: 여기에 3D 에셋을 선택하는 리스트 UI 구현
                Spacer()
                
                GlowingCapsuleButton(buttonText: "생성하기", action: {
                    onCreateEntity(selectedEntityID)
                })
                .padding(.bottom, 20)
            }
            .frame(width: 680, height: 440)
            .padding()
            .glassBackgroundEffect()
            
        }
    }
}

#Preview {
    AssetListView(
        isPresented: .constant(true),
        onCreateEntity: { entityID in
            print("Creating entity: \(entityID)")
        }
    )
}
