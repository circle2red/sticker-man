//
//  SearchBar.swift
//  stickers-gen
//
//  Created on 2025/12/22.
//

import SwiftUI

/// 搜索栏组件（带自动补全）
struct SearchBar: View {
    @Binding var searchText: String
    var suggestions: [String]
    var onSuggestionTap: (String) -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 搜索输入框
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("搜索标签或文件名...", text: $searchText)
                    .focused($isFocused)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)

            // 自动补全建议
            if !suggestions.isEmpty && isFocused {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(action: {
                            onSuggestionTap(suggestion)
                            isFocused = false
                        }) {
                            HStack {
                                Image(systemName: "tag")
                                    .foregroundColor(.blue)
                                    .font(.caption)

                                Text(suggestion)
                                    .foregroundColor(.primary)

                                Spacer()

                                Image(systemName: "arrow.up.backward")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }

                        if suggestion != suggestions.last {
                            Divider()
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                .padding(.top, 4)
            }
        }
    }
}

#Preview {
    SearchBar(
        searchText: .constant("表情"),
        suggestions: ["表情包", "表情大全", "搞笑表情"],
        onSuggestionTap: { _ in }
    )
    .padding()
}
