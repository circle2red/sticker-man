//
//  EditorPlaceholderView.swift
//  stickers-gen
//
//  Created on 2025/12/22.
//

import SwiftUI


/// AI创作页面占位符
struct AIGeneratorPlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 70))
                .foregroundColor(.purple)

            Text("AI创作")
                .font(.title)
                .fontWeight(.bold)

            Text("Phase 6 即将实现")
                .font(.body)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(icon: "photo", text: "基于图片生成")
                FeatureRow(icon: "text.bubble", text: "文字描述生成")
                FeatureRow(icon: "cpu", text: "多种AI模型")
                FeatureRow(icon: "square.grid.3x3", text: "批量生成")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding()
    }
}

/// 功能行组件
struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(text)
                .font(.body)

            Spacer()
        }
    }
}


#Preview("AI") {
    AIGeneratorPlaceholderView()
}
