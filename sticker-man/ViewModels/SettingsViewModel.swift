//
//  SettingsViewModel.swift
//  stickers-gen
//
//  Created on 2025/12/22.
//

import Foundation
import SwiftUI

/// 设置视图模型
@MainActor
class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var storageInfo: StorageInfo?
    @Published var isLoadingStorage = false
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var showClearCacheConfirmation = false

    // MARK: - AI Config
    @Published var aiConfig: AIConfig = AIConfig.load()

    // MARK: - User Preferences
    @AppStorage(Constants.UserDefaultsKeys.showDeleteConfirmation)
    var showDeleteConfirmation: Bool = true

    // MARK: - Services
    private let fileStorageManager = FileStorageManager.shared
    private let databaseManager = DatabaseManager.shared
    private let aiService = AIService.shared

    // MARK: - Initialization
    init() {
        Task {
            await loadStorageInfo()
        }
    }

    // MARK: - Storage
    /// 加载存储空间信息
    func loadStorageInfo() async {
        isLoadingStorage = true
        defer { isLoadingStorage = false }

        storageInfo = await fileStorageManager.getStorageInfo()
    }

    /// 清除所有（文件和数据库）
    func clearData() async {
        do {
            // 清除文件
            try await fileStorageManager.clearAllCache()

            // 清除数据库
            try await databaseManager.clearAllData()

            // 重新加载存储信息
            await loadStorageInfo()

            print("✅ All data cleared successfully")
        } catch {
            showErrorMessage("清除失败: \(error.localizedDescription)")
        }
    }

    // MARK: - AI Config
    /// 保存AI配置
    func saveAIConfig() {
        aiConfig.save()
        print("✅ AI config saved")
    }

    /// 测试AI连接
    func testAIConnection() async -> Bool {
        guard aiConfig.isValid else {
            showErrorMessage("请先完整填写API配置")
            return false
        }

        print("🔍 Testing AI connection...")

        do {
            let success = try await aiService.testConnection(config: aiConfig)
            print("✅ AI connection test successful")
            return success
        } catch {
            showErrorMessage("连接测试失败: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Error Handling
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
        print("❌ \(message)")
    }

    func clearError() {
        errorMessage = nil
        showError = false
    }
}
