//
//  EmptyStateView.swift
//  stickers-gen
//
//  Created on 2025/12/22.
//

import SwiftUI

/// 空状态视图
struct EmptyStateView: View {
    var onImportTap: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 70))
                .foregroundColor(.gray)

            Text("还没有表情包")
                .font(.title2)
                .fontWeight(.semibold)

            Text("点击右上角按钮导入图片")
                .font(.body)
                .foregroundColor(.secondary)

            Button(action: onImportTap) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("导入表情包")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(10)
            }
            .padding(.top, 10)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView(onImportTap: {})
}
