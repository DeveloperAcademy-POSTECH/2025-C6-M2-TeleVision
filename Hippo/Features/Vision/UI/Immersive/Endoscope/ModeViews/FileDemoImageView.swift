//
//  FileDemoImageView.swift
//  Hippo
//
//  Image demo view using TextureResource + UnlitMaterial
//  Displays demo-image from VisionAssets as a flat 2D plane
//

import SwiftUI
import RealityKit
import os.log

/// Image demo view - displays demo-image using TextureResource and UnlitMaterial
/// This mode shows a static image on a flat plane
struct FileDemoImageView: View {
    private let logger = Logger(
        subsystem: "com.television.hippo",
        category: "FileDemoImageView"
    )

    // Entity name for tracking
    private static let entityName = "image-demo-entity"
    private static let entityScale = SIMD3<Float>(0.4, 0.4, 0.4)

    var body: some View {
        #if os(visionOS)
        RealityView { content in
            logger.info("FileDemoImageView: Creating RealityView for image demo")

            // Load image from VisionAssets
            guard let uiImage = UIImage(named: "demo-image") else {
                logger.error("❌ demo-image not found in VisionAssets")
                return
            }

            guard let cgImage = uiImage.cgImage else {
                logger.error("❌ Failed to get CGImage from UIImage")
                return
            }

            logger.info("   Image size: \(Int(uiImage.size.width)) × \(Int(uiImage.size.height))")

            // Create TextureResource from CGImage
            do {
                let texture = try await TextureResource(
                    image: cgImage,
                    options: .init(semantic: .color)
                )

                // Create UnlitMaterial with texture
                var material = UnlitMaterial()
                material.color = .init(texture: .init(texture))

                // Calculate plane dimensions based on image aspect ratio
                let aspectRatio = Float(uiImage.size.width / uiImage.size.height)
                let planeHeight: Float = 0.9
                let planeWidth = planeHeight * aspectRatio

                // Create plane entity
                let planeMesh = MeshResource.generatePlane(width: planeWidth, height: planeHeight)
                let planeEntity = ModelEntity(mesh: planeMesh, materials: [material])
                planeEntity.name = Self.entityName
                planeEntity.position = SIMD3<Float>(0, 0, 0)
                planeEntity.scale = Self.entityScale

                content.add(planeEntity)

                logger.info("✅ FileDemoImageView: Image display ready")
                logger.info("   Plane size: \(planeWidth) × \(planeHeight)")
                logger.info("   Aspect ratio: \(aspectRatio)")

            } catch {
                logger.error("❌ Failed to create TextureResource: \(error.localizedDescription)")
            }

        } update: { _ in
            // No update needed for static image
        }
        .frame(depth: 0)
        .onAppear {
            logger.info("FileDemoImageView appeared")
        }
        .onDisappear {
            logger.info("FileDemoImageView disappeared")
        }
        #else
        Image("demo-image")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        #endif
    }
}

// MARK: - Preview

#Preview {
    FileDemoImageView()
}
