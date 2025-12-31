//
//  AIConfig.swift
//  stickers-gen
//
//  Created on 2025/12/22.
//

import Foundation

/// AI配置数据模型
struct AIConfig: Codable {
    var apiEndpoint: String
    var apiKey: String
    var modelName: String

    init(
        apiEndpoint: String = Constants.AI.defaultEndpoint,
        apiKey: String = "",
        modelName: String = Constants.AI.defaultModelName
    ) {
        self.apiEndpoint = apiEndpoint
        self.apiKey = apiKey
        self.modelName = modelName
    }

    // MARK: - UserDefaults Storage
    /// 从UserDefaults加载配置
    static func load() -> AIConfig {
        let defaults = UserDefaults.standard
        return AIConfig(
            apiEndpoint: defaults.string(forKey: Constants.UserDefaultsKeys.apiEndpoint) ?? Constants.AI.defaultEndpoint,
            apiKey: defaults.string(forKey: Constants.UserDefaultsKeys.apiKey) ?? "",
            modelName: defaults.string(forKey: Constants.UserDefaultsKeys.modelName) ?? Constants.AI.defaultModelName
        )
    }

    /// 保存配置到UserDefaults
    func save() {
        let defaults = UserDefaults.standard
        defaults.set(apiEndpoint, forKey: Constants.UserDefaultsKeys.apiEndpoint)
        defaults.set(apiKey, forKey: Constants.UserDefaultsKeys.apiKey)
        defaults.set(modelName, forKey: Constants.UserDefaultsKeys.modelName)
    }

    /// 清除配置
    static func clear() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Constants.UserDefaultsKeys.apiEndpoint)
        defaults.removeObject(forKey: Constants.UserDefaultsKeys.apiKey)
        defaults.removeObject(forKey: Constants.UserDefaultsKeys.modelName)
    }

    /// 检查配置是否完整
    var isValid: Bool {
        return !apiEndpoint.isEmpty && !apiKey.isEmpty && !modelName.isEmpty
    }
}
