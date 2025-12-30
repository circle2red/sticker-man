//
//  ShareSheet.swift
//  stickers-gen
//
//  Created on 2025/12/22.
//

import SwiftUI
import UIKit

/// 系统分享Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
