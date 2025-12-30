//
//  StickerImageView.swift
//  stickers-gen
//
//  Created on 2025/12/26.
//

import SwiftUI

/// 单个表情包图片视图（支持缩放和双击重置）
struct StickerImageView: View {
    let sticker: Sticker
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    // 限制缩放范围
                                    if scale < 1.0 {
                                        withAnimation {
                                            scale = 1.0
                                            lastScale = 1.0
                                        }
                                    } else if scale > 3.0 {
                                        withAnimation {
                                            scale = 3.0
                                            lastScale = 3.0
                                        }
                                    }
                                }
                        )
                        .onTapGesture(count: 2) {
                            // 双击重置缩放
                            withAnimation {
                                scale = 1.0
                                lastScale = 1.0
                            }
                        }
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .task {
            image = await FileStorageManager.shared.loadImage(at: sticker.filePath)
        }
    }
}
