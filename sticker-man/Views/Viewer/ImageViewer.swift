//
//  ImageViewerView.swift
//  stickers-gen
//
//  Created on 2025/12/22.
//

import SwiftUI

/// 图片查看器（全屏查看，支持左右滑动）
struct ImageViewerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: StickerLibraryViewModel

    let initialIndex: Int
    var onMenuAction: (MenuAction, Sticker) -> Void

    @State private var currentIndex: Int
    @State private var showingMenu = false

    init(viewModel: StickerLibraryViewModel, initialIndex: Int, onMenuAction: @escaping (MenuAction, Sticker) -> Void) {
        self.viewModel = viewModel
        self.initialIndex = initialIndex
        self.onMenuAction = onMenuAction
        self._currentIndex = State(initialValue: initialIndex)
    }

    var currentSticker: Sticker? {
        guard !viewModel.filteredStickers.isEmpty,
              currentIndex >= 0,
              currentIndex < viewModel.filteredStickers.count else {
            return nil
        }
        return viewModel.filteredStickers[currentIndex]
    }

    var body: some View {
        NavigationStack {
            // 如果没有图片，显示空状态
            if viewModel.filteredStickers.isEmpty {
                emptyStateView
            } else {
                imageViewerContent
            }
        }
        .confirmationDialog(
            currentSticker?.filename ?? "操作",
            isPresented: $showingMenu,
            titleVisibility: .visible
        ) {
            menuButtons
        }
    }

    // MARK: - View Components

    private var emptyStateView: some View {
        VStack {
            Text("没有可显示的图片")
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }

    private var imageViewerContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // TabView 实现左右滑动
            TabView(selection: $currentIndex) {
                ForEach(Array(viewModel.filteredStickers.enumerated()), id: \.element.id) { index, sticker in
                    StickerImageView(sticker: sticker)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // 顶部信息栏
            topBar
        }
        .navigationBarHidden(true)
        .statusBar(hidden: true)
    }

    private var topBar: some View {
        VStack {
            HStack {
                closeButton

                Spacer()

                if let currentSticker = currentSticker {
                    stickerInfo(currentSticker)
                }

                Spacer()

                menuButton
            }
            .padding()

            Spacer()
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.title3)
                .foregroundColor(.white)
                .padding(12)
                .background(Color.black.opacity(0.5))
                .clipShape(Circle())
        }
    }

    private func stickerInfo(_ sticker: Sticker) -> some View {
        VStack(alignment: .center, spacing: 2) {
            Text(sticker.filename)
                .font(.headline)
                .foregroundColor(.white)

            Text("\(currentIndex + 1) / \(viewModel.filteredStickers.count)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
    }

    private var menuButton: some View {
        Button {
            showingMenu = true
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .foregroundColor(.white)
                .padding(12)
                .background(Color.black.opacity(0.5))
                .clipShape(Circle())
        }
    }

    @ViewBuilder
    private var menuButtons: some View {
        if let sticker = currentSticker {
            StickerContextMenu(sticker: sticker) { action in
                onMenuAction(action, sticker)
            }
            .buttons
        }
    }
}

// MARK: - Preview

#Preview {
    // 创建一个简化的包装视图来处理预览
    struct PreviewWrapper: View {
        @StateObject private var viewModel = StickerLibraryViewModel()

        var body: some View {
            Color.clear
                .onAppear {
                    // 在视图出现时设置测试数据
                    viewModel.stickers = [
                        Sticker(
                            id: "1",
                            filename: "test1.jpg",
                            filePath: "test1.jpg",
                            fileSize: 50000,
                            width: 500,
                            height: 500,
                            format: "jpg"
                        ),
                        Sticker(
                            id: "2",
                            filename: "test2.jpg",
                            filePath: "test2.jpg",
                            fileSize: 60000,
                            width: 500,
                            height: 500,
                            format: "jpg",
                            isPinned: true
                        )
                    ]
                    viewModel.filteredStickers = viewModel.stickers
                }
                .fullScreenCover(isPresented: .constant(true)) {
                    ImageViewerView(
                        viewModel: viewModel,
                        initialIndex: 0,
                        onMenuAction: { _, _ in }
                    )
                }
        }
    }

    return PreviewWrapper()
}
