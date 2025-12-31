# Sticker Man

一款 iOS 贴纸管理和创建应用，支持手动创建和 AI 生成贴纸。

## 功能特性

- **贴纸库管理** - 浏览、搜索和管理你的贴纸收藏
- **手动创建** - 使用内置编辑器创建自定义贴纸
- **AI 生成** - 使用 AI 自动生成创意贴纸
- **标签系统** - 使用标签组织和分类贴纸
- **导入导出** - 轻松导入和分享贴纸

## 技术栈

- **语言**: Swift 5.0
- **框架**: SwiftUI
- **平台**: iOS
- **架构**: MVVM
- **数据存储**: 本地数据库 + 文件存储

## 项目结构

```
sticker-man/
├── Models/              # 数据模型
│   ├── Sticker.swift
│   ├── Tag.swift
│   └── AIConfig.swift
├── Views/               # 视图层
│   ├── Editor/         # 编辑器相关视图
│   ├── StickerLibrary/ # 贴纸库视图
│   ├── Settings/       # 设置页面
│   └── MainLayout/     # 主布局组件
├── ViewModels/          # 视图模型
├── Services/            # 服务层
│   ├── Database/       # 数据库管理
│   ├── Storage/        # 文件存储
│   └── AIService.swift # AI 服务
└── Utilities/           # 工具类和扩展
```

## 开发环境

- Xcode 14.0+
- iOS 15.0+
- Swift 5.0+

## 构建和运行

1. 克隆项目
```bash
git clone <repository-url>
cd stickers-man
```

2. 打开 Xcode 项目
```bash
open sticker-man.xcodeproj
```

3. 选择目标设备或模拟器
4. 点击 Run 按钮或按 `Cmd + R` 运行应用

