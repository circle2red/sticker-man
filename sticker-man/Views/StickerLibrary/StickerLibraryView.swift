//
//  StickerLibraryView.swift
//  stickers-gen
//
//  Created on 2025/12/22.
//

import SwiftUI

/// 可识别的图片包装类，用于 fullScreenCover
struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// 可识别的查看器索引包装类，用于 fullScreenCover
struct IdentifiableViewerIndex: Identifiable {
    let id = UUID()
    let index: Int
}

/// 可识别的URL包装类，用于 sheet
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

/// 待执行的操作类型
enum PendingAction {
    case editTags(Sticker)
    case editImage(Sticker)
    case rename(Sticker)
}

/// 表情包图库视图
struct StickerLibraryView: View {
    @StateObject private var viewModel = StickerLibraryViewModel()

    // Sheet states
    @State private var showingTagEditor = false
    @State private var showingActionSheet = false
    @State private var showingExportMenu = false
    @State private var showingImport = false
    @State private var viewerIndex: IdentifiableViewerIndex?
    @State private var selectedSticker: Sticker?
    @State private var editingTags: [String] = []
    @State private var allTags: [String] = []
    @State private var editorImage: IdentifiableImage?

    // Rename dialog
    @State private var showingRenameDialog = false
    @State private var renamingSticker: Sticker?
    @State private var newStickerName: String = ""

    // Selection mode
    @State private var isSelectionMode = false
    @State private var selectedStickers: Set<String> = []
    @State private var showingBatchDeleteConfirmation = false

    // Delete confirmation
    @State private var showingDeleteConfirmation = false
    @State private var stickerToDelete: Sticker?
    @AppStorage(Constants.UserDefaultsKeys.showDeleteConfirmation)
    private var deleteConfirmationEnabled: Bool = true

    // Pending action - 用于在关闭一个 fullScreenCover 后执行另一个操作
    @State private var pendingAction: PendingAction?

    // Share
    @State private var shareItem: IdentifiableURL?

    var body: some View {
        ZStack {
            if viewModel.isEmpty {
                // 空状态
                EmptyStateView {
                    showingImport = true
                }
            } else {
                // 内容视图
                VStack(spacing: 0) {
                    // 搜索栏
                    SearchBar(
                        searchText: $viewModel.searchText,
                        suggestions: viewModel.searchSuggestions,
                        onSuggestionTap: { suggestion in
                            viewModel.applySearchSuggestion(suggestion)
                        }
                    )
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    // 列表内容
                    if viewModel.viewMode == .grid {
                        GridView(
                            stickers: viewModel.filteredStickers,
                            isSelectionMode: isSelectionMode,
                            selectedStickers: selectedStickers,
                            onStickerTap: { sticker in
                                handleStickerTap(sticker)
                            },
                            onStickerLongPress: { sticker in
                                handleStickerLongPress(sticker)
                            }
                        )
                    } else {
                        ListMenuView(
                            stickers: viewModel.filteredStickers,
                            isSelectionMode: isSelectionMode,
                            selectedStickers: selectedStickers,
                            onStickerTap: { sticker in
                                handleStickerTap(sticker)
                            },
                            onStickerLongPress: { sticker in
                                handleStickerLongPress(sticker)
                            }
                        )
                    }
                }
            }

            // 加载指示器
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }

            // 批量操作工具栏
            if isSelectionMode && !selectedStickers.isEmpty {
                VStack {
                    Spacer()
                    selectionToolbar
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    if !viewModel.isEmpty && !isSelectionMode {
                        Button(action: {
                            viewModel.toggleViewMode()
                        }) {
                            Image(systemName: viewModel.viewMode == .grid ? "list.bullet" : "square.grid.2x2")
                                .font(.title3)
                        }
                    }

                    if !viewModel.isEmpty {
                        Button(action: {
                            toggleSelectionMode()
                        }) {
                            if isSelectionMode {
                                Text("取消")
                            } else {
                                Image(systemName: "checkmark.circle")
                                    .font(.title3)
                            }
                        }
                    }
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .sheet(isPresented: $showingTagEditor) {
            TagEditorView(tags: $editingTags, allTags: allTags)
                .onDisappear {
                    // 保存标签
                    if let sticker = selectedSticker {
                        Task {
                            await viewModel.updateStickerTags(sticker, tags: editingTags)
                        }
                    }
                }
        }
        .sheet(item: $shareItem) { identifiableURL in
            ShareSheet(items: [identifiableURL.url])
        }
        .sheet(isPresented: $showingImport) {
            ImportView()
                .onDisappear {
                    // 导入完成后刷新列表
                    Task {
                        await viewModel.refresh()
                    }
                }
        }
        .fullScreenCover(item: $viewerIndex) { identifiableIndex in
            ImageViewerView(
                viewModel: viewModel,
                initialIndex: identifiableIndex.index,
                onMenuAction: { action, sticker in
                    handleMenuAction(action, sticker: sticker)
                }
            )
            .onDisappear {
                // ImageViewerView 完全关闭后，执行 pending action
                if let action = pendingAction {
                    pendingAction = nil
                    executePendingAction(action)
                }
            }
        }
        .fullScreenCover(item: $editorImage) { identifiableImage in
            EditorView(image: identifiableImage.image, sticker: selectedSticker)
                .onDisappear {
                    // 编辑完成后刷新列表并清理状态
                    Task {
                        await viewModel.refresh()
                    }
                    // 清理编辑器图片状态
                    self.editorImage = nil
                    self.selectedSticker = nil
                }
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) {
                viewModel.clearError()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .confirmationDialog(
            selectedSticker?.filename ?? "操作",
            isPresented: $showingActionSheet,
            titleVisibility: .visible
        ) {
            if let sticker = selectedSticker {
                StickerContextMenu(sticker: sticker) { action in
                    handleMenuAction(action, sticker: sticker)
                }
                .buttons
            }
        }
        .confirmationDialog(
            "分享/导出",
            isPresented: $showingExportMenu,
            titleVisibility: .visible
        ) {
            if let sticker = selectedSticker {
                StickerContextMenu(sticker: sticker) { action in
                    handleMenuAction(action, sticker: sticker)
                }
                .exportButtons
            }
        }
        .alert("确认删除", isPresented: $showingBatchDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                performBatchDelete()
            }
        } message: {
            Text("确定要删除选中的 \(selectedStickers.count) 个表情包吗？此操作无法撤销。")
        }
        .alert("确认删除", isPresented: $showingDeleteConfirmation) {
            Button("取消", role: .cancel) {
                stickerToDelete = nil
            }
            Button("删除", role: .destructive) {
                if let sticker = stickerToDelete {
                    performDelete(sticker)
                    stickerToDelete = nil
                }
            }
        } message: {
            if let sticker = stickerToDelete {
                Text("确定要删除“\(sticker.filename)”吗？此操作无法撤销。")
            }
        }
        .alert("重命名", isPresented: $showingRenameDialog) {
            TextField("新名称", text: $newStickerName)
            Button("取消", role: .cancel) {
                newStickerName = ""
                renamingSticker = nil
            }
            Button("确定") {
                performRename()
            }
        } message: {
            if let sticker = renamingSticker {
                let ext = (sticker.filename as NSString).pathExtension
                if !ext.isEmpty {
                    Text("请输入新的名称（扩展名 .\(ext) 将自动保留）")
                } else {
                    Text("请输入新的名称")
                }
            } else {
                Text("请输入新的名称")
            }
        }
    }

    // MARK: - Actions
    private func handleStickerTap(_ sticker: Sticker) {
        // 多选模式下，点击切换选中状态
        if isSelectionMode {
            if selectedStickers.contains(sticker.id) {
                selectedStickers.remove(sticker.id)
            } else {
                selectedStickers.insert(sticker.id)
            }
            return
        }

        // 非多选模式下，打开查看器
        // 找到当前图片在列表中的索引
        if let index = viewModel.filteredStickers.firstIndex(where: { $0.id == sticker.id }) {
            // 将索引包装为 IdentifiableViewerIndex，这会自动触发 fullScreenCover
            viewerIndex = IdentifiableViewerIndex(index: index)
        }
    }

    private func handleStickerLongPress(_ sticker: Sticker) {
        selectedSticker = sticker
        showingActionSheet = true
    }

    private func handleEditTags(_ sticker: Sticker) {
        selectedSticker = sticker
        editingTags = sticker.tags
        Task {
            allTags = await viewModel.getAllTags()
            await MainActor.run {
                showingTagEditor = true
            }
        }
    }

    private func handleEditImage(_ sticker: Sticker) {
        Task { @MainActor in
            if let image = await FileStorageManager.shared.loadImage(at: sticker.filePath) {
                selectedSticker = sticker
                // 将 UIImage 包装为 IdentifiableImage，这会自动触发 fullScreenCover
                editorImage = IdentifiableImage(image: image)
            }
        }
    }

    private func handleTogglePin(_ sticker: Sticker) {
        Task {
            await viewModel.togglePin(sticker)
        }
    }

    private func handleExport(_ sticker: Sticker, format: String) {
        Task {
            if let url = await viewModel.exportSticker(sticker, format: format) {
                await MainActor.run {
                    shareItem = IdentifiableURL(url: url)
                }
            }
        }
    }

    private func handleShare(_ sticker: Sticker) {
        Task {
            // 原格式分享：使用sticker的原始格式
            if let url = await viewModel.exportSticker(sticker, format: sticker.format) {
                await MainActor.run {
                    shareItem = IdentifiableURL(url: url)
                }
            }
        }
    }

    private func handleDelete(_ sticker: Sticker) {
        if deleteConfirmationEnabled {
            // 显示确认对话框
            stickerToDelete = sticker
            showingDeleteConfirmation = true
        } else {
            // 直接删除
            performDelete(sticker)
        }
    }

    private func performDelete(_ sticker: Sticker) {
        Task {
            await viewModel.deleteSticker(sticker)
        }
    }

    private func handleRename(_ sticker: Sticker) {
        renamingSticker = sticker
        // 提取文件名（不包含扩展名）
        let filename = (sticker.filename as NSString).deletingPathExtension
        newStickerName = filename
        showingRenameDialog = true
    }

    private func performRename() {
        guard let sticker = renamingSticker else { return }

        // 获取原始文件的扩展名
        let fileExtension = (sticker.filename as NSString).pathExtension
        // 组合新文件名和原扩展名
        let newFilenameWithExtension = fileExtension.isEmpty ? newStickerName : "\(newStickerName).\(fileExtension)"

        Task {
            let success = await viewModel.renameSticker(sticker, newName: newFilenameWithExtension)
            await MainActor.run {
                if success {
                    newStickerName = ""
                    renamingSticker = nil
                }
            }
        }
    }

    private func handleMenuAction(_ action: MenuAction, sticker: Sticker) {
        // 检查是否在查看器中
        let isInViewer = viewerIndex != nil

        // 需要关闭查看器的操作
        if action == .delete || action == .editTags || action == .editImage || action == .rename {
            // 如果在查看器中，需要先关闭查看器
            if isInViewer {
                // 设置 pending action 以便在查看器关闭后执行
                if action == .editTags {
                    pendingAction = .editTags(sticker)
                } else if action == .editImage {
                    pendingAction = .editImage(sticker)
                } else if action == .rename {
                    pendingAction = .rename(sticker)
                }
                // 关闭查看器
                viewerIndex = nil

                // 删除操作直接执行
                if action == .delete {
                    handleDelete(sticker)
                }
            } else {
                // 不在查看器中，直接执行操作
                switch action {
                case .editTags:
                    handleEditTags(sticker)
                case .editImage:
                    handleEditImage(sticker)
                case .rename:
                    handleRename(sticker)
                case .delete:
                    handleDelete(sticker)
                default:
                    break
                }
            }
            return
        }

        // 其他操作直接执行，不关闭查看器
        switch action {
        case .togglePin:
            handleTogglePin(sticker)
        case .showExportMenu:
            showingExportMenu = true
        case .shareOriginal:
            handleShare(sticker)
        case .exportJPG:
            handleExport(sticker, format: "jpg")
        case .exportPNG:
            handleExport(sticker, format: "png")
        case .exportGIF:
            handleExport(sticker, format: "gif")
        default:
            break
        }
    }

    // 执行 pending action
    private func executePendingAction(_ action: PendingAction) {
        switch action {
        case .editTags(let sticker):
            handleEditTags(sticker)
        case .editImage(let sticker):
            handleEditImage(sticker)
        case .rename(let sticker):
            handleRename(sticker)
        }
    }

    // MARK: - Selection Mode
    private func toggleSelectionMode() {
        isSelectionMode.toggle()
        if !isSelectionMode {
            selectedStickers.removeAll()
        }
    }

    private func handleBatchDelete() {
        showingBatchDeleteConfirmation = true
    }

    private func performBatchDelete() {
        Task {
            await viewModel.batchDelete(stickerIds: Array(selectedStickers))
            selectedStickers.removeAll()
            isSelectionMode = false
        }
    }

    private func handleBatchExport() {
        Task {
            if let url = await viewModel.batchExportToZip(stickerIds: Array(selectedStickers)) {
                await MainActor.run {
                    shareItem = IdentifiableURL(url: url)
                }
            }
        }
    }

    // MARK: - Selection Toolbar
    private var selectionToolbar: some View {
        HStack(spacing: 20) {
            Button(action: handleBatchDelete) {
                VStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.title2)
                    Text("删除")
                        .font(.caption)
                }
                .foregroundColor(.red)
            }

            Spacer()

            Text("\(selectedStickers.count) 已选")
                .font(.headline)

            Spacer()

            Button(action: handleBatchExport) {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.down.doc")
                        .font(.title2)
                    Text("导出ZIP")
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.1), radius: 8, y: -2)
    }
}

#Preview {
    StickerLibraryView()
}
