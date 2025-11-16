//
//  ThumbnailLoader.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/14/25.
//

import Foundation
import QuickLookThumbnailing
import AppKit
import Combine

@Observable
class ThumbnailLoader {
    var image :NSImage?
    
    func load(for url: URL, size: CGSize = .init(width: 80, height: 80)) {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let request = QLThumbnailGenerator.Request(
                   fileAt: url,
                   size: size,
                   scale: scale,
                   representationTypes: .thumbnail
               )
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] rep, error in
            guard let rep, error == nil else { return }
            DispatchQueue.main.async {
                self?.image = rep.nsImage
            }
        }
    }
}
