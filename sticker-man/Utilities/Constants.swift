//
//  Constants.swift
//  stickers-gen
//
//  Created on 2025/12/22.
//

import Foundation

enum Constants {
    // MARK: - File Storage
    enum Storage {
        static let appDirectoryName = "Stickers"
        static let stickersDirectoryName = "stickers"
        static let thumbnailsDirectoryName = "thumbnails"

        // 图片压缩参数
        static let maxImageDimension: CGFloat = 1000 // 最大边长
        static let maxFileSize: Int = 200 * 1024 // 200KB
        static let thumbnailSize: CGFloat = 100 // 缩略图尺寸
        static let compressionQuality: CGFloat = 0.8 // JPEG压缩质量
    }

    // MARK: - Database
    enum Database {
        static let databaseName = "stickers.db"
    }

    // MARK: - UserDefaults Keys
    enum UserDefaultsKeys {
        static let apiEndpoint = "ai_api_endpoint"
        static let apiKey = "ai_api_key"
        static let modelName = "ai_model_name"
        static let showDeleteConfirmation = "show_delete_confirmation"
    }

    // MARK: - UI
    enum UI {
        static let gridColumns = 3
        static let searchDebounceMilliseconds = 300
        static let maxSearchSuggestions = 5
        static let maxSearchHistory = 5
    }

    // MARK: - AI
    enum AI {
        static let defaultEndpoint = "https://openrouter.ai/api/v1/chat/completions"
        static let defaultModelName = "google/gemini-2.5-flash-image"
        static let timeoutSeconds = 30.0
        static let maxRetries = 2
    }
}
