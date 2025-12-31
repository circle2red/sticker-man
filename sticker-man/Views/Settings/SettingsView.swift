//
//  SettingsView.swift
//  stickers-gen
//
//  Created on 2025/12/22.
//

import SwiftUI

/// 设置视图
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showingImport = false
    @State private var showingStorageDetail = false

    var body: some View {
        List {
            // 导入部分
            Section("导入") {
                Button {
                    showingImport = true
                } label: {
                    Label("导入图片", systemImage: "photo.on.rectangle.angled")
                }
            }

            // AI配置
            Section("AI配置") {
                NavigationLink {
                    AIConfigDetailView(viewModel: viewModel)
                } label: {
                    Label("AI设置", systemImage: "cpu")
                }

                HStack {
                    Text("当前模型")
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(viewModel.aiConfig.modelName.isEmpty ? "未配置" : viewModel.aiConfig.modelName)
                        .foregroundColor(viewModel.aiConfig.isValid ? .primary : .red)
                        .lineLimit(1)
                }
            }

            // 存储管理
            Section("存储") {
                Button {
                    showingStorageDetail = true
                } label: {
                    HStack {
                        Label("存储空间", systemImage: "internaldrive")
                            .foregroundColor(.primary)

                        Spacer()

                        if viewModel.isLoadingStorage {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if let storageInfo = viewModel.storageInfo {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(storageInfo.formattedSize)
                                    .foregroundColor(.secondary)

                                Text("\(storageInfo.fileCount) 个文件")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }

            // 偏好设置
            Section("偏好设置") {
                Toggle(isOn: $viewModel.showDeleteConfirmation) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("删除确认")
                        Text("删除表情包前显示确认提示")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // 关于
            Section("关于") {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                Button {
                    // 关于页面
                } label: {
                    Label("关于应用", systemImage: "info.circle")
                        .foregroundColor(.primary)
                }
            }
        }
        .sheet(isPresented: $showingImport) {
            ImportView()
                .onDisappear {
                    // 导入完成后刷新存储信息
                    Task {
                        await viewModel.loadStorageInfo()
                    }
                }
        }
        .sheet(isPresented: $showingStorageDetail) {
            StorageDetailView(viewModel: viewModel)
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
            "确认清除所有数据",
            isPresented: $viewModel.showClearCacheConfirmation,
            titleVisibility: .visible
        ) {
            Button("清除所有", role: .destructive) {
                Task {
                    await viewModel.clearData()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这将删除所有表情包文件、缩略图和数据库记录。用户配置（如API密钥）将被保留。此操作不可撤销。")
        }
        .refreshable {
            await viewModel.loadStorageInfo()
        }
    }
}

// MARK: - Storage Detail View
struct StorageDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            List {
                if let storageInfo = viewModel.storageInfo {
                    Section("存储统计") {
                        HStack {
                            Text("总大小")
                            Spacer()
                            Text(storageInfo.formattedSize)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("文件数量")
                            Spacer()
                            Text("\(storageInfo.fileCount)")
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("平均文件大小")
                            Spacer()
                            if storageInfo.fileCount > 0 {
                                let avgSize = storageInfo.totalSize / Int64(storageInfo.fileCount)
                                Text(formatFileSize(avgSize))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("-")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Section("操作") {
                        Button {
                            Task {
                                await viewModel.loadStorageInfo()
                            }
                        } label: {
                            Label("刷新统计", systemImage: "arrow.clockwise")
                        }

                        Button(role: .destructive) {
                            viewModel.showClearCacheConfirmation = true
                            dismiss()
                        } label: {
                            Label("清除所有", systemImage: "trash")
                        }
                    }
                } else {
                    Text("加载中...")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("存储空间")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("完成") {
                dismiss()
            })
        }
    }

    // MARK: - Helper Methods
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
