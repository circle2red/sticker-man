//
//  StickerContextMenu.swift
//  stickers-gen
//
//  Created on 2025/12/30.
//

import SwiftUI

enum MenuAction: Equatable {
    case editTags
    case editImage
    case rename
    case togglePin
    case exportJPG
    case exportPNG
    case share
    case delete
}

/// 可重用的表情包上下文菜单
/// 提供统一的菜单按钮，用于长按菜单和ImageViewer菜单
struct StickerContextMenu {
    let sticker: Sticker
    let onAction: (MenuAction) -> Void

    /// 生成菜单按钮
    @ViewBuilder
    var buttons: some View {
        Button("编辑标签") {
            onAction(.editTags)
        }

        Button("编辑图片") {
            onAction(.editImage)
        }

        Button("重命名") {
            onAction(.rename)
        }

        Button(sticker.isPinned ? "取消置顶" : "置顶") {
            onAction(.togglePin)
        }

        Button("导出为JPG") {
            onAction(.exportJPG)
        }

        Button("导出为PNG") {
            onAction(.exportPNG)
        }

        Button("分享") {
            onAction(.share)
        }

        Button("删除", role: .destructive) {
            onAction(.delete)
        }

        Button("取消", role: .cancel) {}
    }
}
