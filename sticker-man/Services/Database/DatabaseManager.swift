//
//  DatabaseManager.swift
//  stickers-gen
//
//  Created on 2025/12/22.
//
//  NOTE: 需要在Xcode中添加SQLite.swift SPM依赖
//  URL: https://github.com/stephencelis/SQLite.swift

import Foundation
import SQLite

/// 数据库管理器（使用Actor确保线程安全）
actor DatabaseManager {
    static let shared = DatabaseManager()

    private var db: Connection?

    private init() {
        Task {
            await initialize()
        }
    }

    // MARK: - Initialization
    /// 初始化数据库
    func initialize() async {
        do {
            let dbPath = URL.appDirectory.appendingPathComponent(Constants.Database.databaseName).path

            // 确保目录存在
            try FileManager.default.ensureDirectoryExists(at: URL.appDirectory)

            db = try Connection(dbPath)

            // 启用外键约束
            try db?.run("PRAGMA foreign_keys = ON")

            // 创建所有表
            if let db = db {
                try DatabaseSchema.createTables(in: db)
            }

            print("✅ Database initialized at: \(dbPath)")
        } catch {
            print("❌ Database initialization failed: \(error)")
        }
    }

    // MARK: - Sticker Operations
    /// 插入表情包
    func insertSticker(_ sticker: Sticker) async throws {
        guard let db = db else { throw DatabaseError.notInitialized }

        let insert = DatabaseSchema.stickers.insert(
            DatabaseSchema.StickersColumns.id <- sticker.id,
            DatabaseSchema.StickersColumns.filename <- sticker.filename,
            DatabaseSchema.StickersColumns.filePath <- sticker.filePath,
            DatabaseSchema.StickersColumns.fileSize <- sticker.fileSize,
            DatabaseSchema.StickersColumns.width <- sticker.width,
            DatabaseSchema.StickersColumns.height <- sticker.height,
            DatabaseSchema.StickersColumns.format <- sticker.format,
            DatabaseSchema.StickersColumns.createdAt <- sticker.createdAt,
            DatabaseSchema.StickersColumns.modifiedAt <- sticker.modifiedAt,
            DatabaseSchema.StickersColumns.isPinned <- sticker.isPinned ? 1 : 0,
            DatabaseSchema.StickersColumns.isFavorite <- sticker.isFavorite ? 1 : 0,
            DatabaseSchema.StickersColumns.usageCount <- sticker.usageCount
        )

        try db.run(insert)

        // 插入标签关联
        for tagName in sticker.tags {
            let tagId = try await getOrCreateTag(name: tagName)
            try await associateStickerWithTag(stickerId: sticker.id, tagId: tagId)
        }
    }

    /// 批量插入表情包
    func insertStickers(_ stickers: [Sticker]) async throws {
        for sticker in stickers {
            try await insertSticker(sticker)
        }
    }

    /// 更新表情包
    func updateSticker(_ sticker: Sticker) async throws {
        guard let db = db else { throw DatabaseError.notInitialized }

        let stickerRow = DatabaseSchema.stickers.filter(DatabaseSchema.StickersColumns.id == sticker.id)
        let update = stickerRow.update(
            DatabaseSchema.StickersColumns.filename <- sticker.filename,
            DatabaseSchema.StickersColumns.filePath <- sticker.filePath,
            DatabaseSchema.StickersColumns.fileSize <- sticker.fileSize,
            DatabaseSchema.StickersColumns.width <- sticker.width,
            DatabaseSchema.StickersColumns.height <- sticker.height,
            DatabaseSchema.StickersColumns.format <- sticker.format,
            DatabaseSchema.StickersColumns.modifiedAt <- sticker.modifiedAt,
            DatabaseSchema.StickersColumns.isPinned <- sticker.isPinned ? 1 : 0,
            DatabaseSchema.StickersColumns.isFavorite <- sticker.isFavorite ? 1 : 0,
            DatabaseSchema.StickersColumns.usageCount <- sticker.usageCount
        )

        try db.run(update)

        // 更新标签关联
        try await removeStickerTags(stickerId: sticker.id)
        for tagName in sticker.tags {
            let tagId = try await getOrCreateTag(name: tagName)
            try await associateStickerWithTag(stickerId: sticker.id, tagId: tagId)
        }
    }

    /// 删除表情包
    func deleteSticker(id: String) async throws {
        guard let db = db else { throw DatabaseError.notInitialized }

        let stickerRow = DatabaseSchema.stickers.filter(DatabaseSchema.StickersColumns.id == id)
        try db.run(stickerRow.delete())
    }

    /// 查询所有表情包
    func fetchAllStickers() async throws -> [Sticker] {
        guard let db = db else { throw DatabaseError.notInitialized }

        var stickers: [Sticker] = []

        for row in try db.prepare(DatabaseSchema.stickers.order(DatabaseSchema.StickersColumns.isPinned.desc, DatabaseSchema.StickersColumns.createdAt.desc)) {
            let sticker = try await parseStickerRow(row)
            stickers.append(sticker)
        }

        return stickers
    }

    /// 根据ID查询表情包
    func fetchSticker(id: String) async throws -> Sticker? {
        guard let db = db else { throw DatabaseError.notInitialized }

        let query = DatabaseSchema.stickers.filter(DatabaseSchema.StickersColumns.id == id)

        if let row = try db.pluck(query) {
            return try await parseStickerRow(row)
        }

        return nil
    }

    /// 检查文件名是否已存在（用于重命名时检测重名）
    func filenameExists(_ filename: String, excludingId: String? = nil) async throws -> Bool {
        guard let db = db else { throw DatabaseError.notInitialized }

        var query = DatabaseSchema.stickers.filter(DatabaseSchema.StickersColumns.filename == filename)

        // 如果提供了excludingId，排除该ID（用于重命名时排除自己）
        if let excludingId = excludingId {
            query = query.filter(DatabaseSchema.StickersColumns.id != excludingId)
        }

        return try db.pluck(query) != nil
    }

    /// 根据标签搜索表情包
    func searchStickers(byTag tagName: String) async throws -> [Sticker] {
        guard let db = db else { throw DatabaseError.notInitialized }

        let query = """
            SELECT DISTINCT s.*
            FROM stickers s
            JOIN sticker_tags st ON s.id = st.sticker_id
            JOIN tags t ON st.tag_id = t.id
            WHERE t.name LIKE ?
            ORDER BY s.is_pinned DESC, s.created_at DESC
        """

        var stickers: [Sticker] = []

        for row in try db.prepare(query, ["%\(tagName)%"]) {
            let sticker = Sticker(
                id: row[0] as! String,
                filename: row[1] as! String,
                filePath: row[2] as! String,
                fileSize: Int(row[3] as! Int64),
                width: Int(row[4] as! Int64),
                height: Int(row[5] as! Int64),
                format: row[6] as! String,
                createdAt: Int(row[7] as! Int64),
                modifiedAt: Int(row[8] as! Int64),
                isPinned: (row[9] as! Int64) == 1,
                isFavorite: (row[10] as! Int64) == 1,
                usageCount: Int(row[11] as! Int64),
                tags: try await fetchTagsForSticker(id: row[0] as! String)
            )
            stickers.append(sticker)
        }

        return stickers
    }

    /// 根据文件名或标签搜索表情包
    func searchStickers(query searchQuery: String) async throws -> [Sticker] {
        guard let db = db else { throw DatabaseError.notInitialized }

        // 搜索文件名或标签
        let query = """
            SELECT DISTINCT s.*
            FROM stickers s
            LEFT JOIN sticker_tags st ON s.id = st.sticker_id
            LEFT JOIN tags t ON st.tag_id = t.id
            WHERE s.filename LIKE ? OR t.name LIKE ?
            ORDER BY s.is_pinned DESC, s.created_at DESC
        """

        var stickers: [Sticker] = []
        let searchPattern = "%\(searchQuery)%"

        for row in try db.prepare(query, [searchPattern, searchPattern]) {
            let sticker = Sticker(
                id: row[0] as! String,
                filename: row[1] as! String,
                filePath: row[2] as! String,
                fileSize: Int(row[3] as! Int64),
                width: Int(row[4] as! Int64),
                height: Int(row[5] as! Int64),
                format: row[6] as! String,
                createdAt: Int(row[7] as! Int64),
                modifiedAt: Int(row[8] as! Int64),
                isPinned: (row[9] as! Int64) == 1,
                isFavorite: (row[10] as! Int64) == 1,
                usageCount: Int(row[11] as! Int64),
                tags: try await fetchTagsForSticker(id: row[0] as! String)
            )
            stickers.append(sticker)
        }

        return stickers
    }

    // MARK: - Tag Operations
    /// 获取或创建标签
    private func getOrCreateTag(name: String) async throws -> Int {
        guard let db = db else { throw DatabaseError.notInitialized }

        // 尝试查找已存在的标签
        let query = DatabaseSchema.tags.filter(DatabaseSchema.TagsColumns.name == name)
        if let row = try db.pluck(query) {
            // 增加使用次数
            let update = query.update(
                DatabaseSchema.TagsColumns.usageCount <- row[DatabaseSchema.TagsColumns.usageCount] + 1
            )
            try db.run(update)
            return row[DatabaseSchema.TagsColumns.id]
        }

        // 创建新标签
        let insert = DatabaseSchema.tags.insert(
            DatabaseSchema.TagsColumns.name <- name,
            DatabaseSchema.TagsColumns.usageCount <- 1,
            DatabaseSchema.TagsColumns.createdAt <- Date().unixTimestamp
        )
        let rowId = try db.run(insert)
        return Int(rowId)
    }

    /// 查询所有标签
    func fetchAllTags() async throws -> [Tag] {
        guard let db = db else { throw DatabaseError.notInitialized }

        var tags: [Tag] = []

        for row in try db.prepare(DatabaseSchema.tags.order(DatabaseSchema.TagsColumns.usageCount.desc)) {
            let tag = Tag(
                id: row[DatabaseSchema.TagsColumns.id],
                name: row[DatabaseSchema.TagsColumns.name],
                usageCount: row[DatabaseSchema.TagsColumns.usageCount],
                createdAt: row[DatabaseSchema.TagsColumns.createdAt]
            )
            tags.append(tag)
        }

        return tags
    }

    /// 搜索标签（用于自动补全）
    func searchTags(query: String, limit: Int = Constants.UI.maxSearchSuggestions) async throws -> [String] {
        guard let db = db else { throw DatabaseError.notInitialized }

        var tagNames: [String] = []

        let search = DatabaseSchema.tags
            .filter(DatabaseSchema.TagsColumns.name.like("%\(query)%"))
            .order(DatabaseSchema.TagsColumns.usageCount.desc)
            .limit(limit)

        for row in try db.prepare(search) {
            tagNames.append(row[DatabaseSchema.TagsColumns.name])
        }

        return tagNames
    }

    /// 关联表情包和标签
    private func associateStickerWithTag(stickerId: String, tagId: Int) async throws {
        guard let db = db else { throw DatabaseError.notInitialized }

        let insert = DatabaseSchema.stickerTags.insert(
            or: .ignore,
            DatabaseSchema.StickerTagsColumns.stickerId <- stickerId,
            DatabaseSchema.StickerTagsColumns.tagId <- tagId,
            DatabaseSchema.StickerTagsColumns.createdAt <- Date().unixTimestamp
        )

        try db.run(insert)
    }

    /// 移除表情包的所有标签关联
    private func removeStickerTags(stickerId: String) async throws {
        guard let db = db else { throw DatabaseError.notInitialized }

        let delete = DatabaseSchema.stickerTags.filter(DatabaseSchema.StickerTagsColumns.stickerId == stickerId)
        try db.run(delete.delete())
    }

    /// 获取表情包的所有标签
    private func fetchTagsForSticker(id: String) async throws -> [String] {
        guard let db = db else { throw DatabaseError.notInitialized }

        var tagNames: [String] = []

        let query = """
            SELECT t.name
            FROM tags t
            JOIN sticker_tags st ON t.id = st.tag_id
            WHERE st.sticker_id = ?
        """

        for row in try db.prepare(query, [id]) {
            tagNames.append(row[0] as! String)
        }

        return tagNames
    }

    // MARK: - Helper Methods
    /// 解析表情包行数据
    private func parseStickerRow(_ row: Row) async throws -> Sticker {
        let id = row[DatabaseSchema.StickersColumns.id]
        return Sticker(
            id: id,
            filename: row[DatabaseSchema.StickersColumns.filename],
            filePath: row[DatabaseSchema.StickersColumns.filePath],
            fileSize: row[DatabaseSchema.StickersColumns.fileSize],
            width: row[DatabaseSchema.StickersColumns.width],
            height: row[DatabaseSchema.StickersColumns.height],
            format: row[DatabaseSchema.StickersColumns.format],
            createdAt: row[DatabaseSchema.StickersColumns.createdAt],
            modifiedAt: row[DatabaseSchema.StickersColumns.modifiedAt],
            isPinned: row[DatabaseSchema.StickersColumns.isPinned] == 1,
            isFavorite: row[DatabaseSchema.StickersColumns.isFavorite] == 1,
            usageCount: row[DatabaseSchema.StickersColumns.usageCount],
            tags: try await fetchTagsForSticker(id: id)
        )
    }

    // MARK: - Clear All Data
    /// 清除所有数据（保留表结构）
    func clearAllData() async throws {
        guard let db = db else { throw DatabaseError.notInitialized }

        // 删除所有数据
        try db.run(DatabaseSchema.stickerTags.delete())
        try db.run(DatabaseSchema.stickers.delete())
        try db.run(DatabaseSchema.tags.delete())

        print("✅ All database data cleared")
    }
}

// MARK: - Database Error
enum DatabaseError: Error {
    case notInitialized
    case queryFailed
    case insertFailed
    case updateFailed
    case deleteFailed
}
