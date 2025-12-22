//
//  EditorViewModel.swift
//  stickers-gen
//
//  Created on 2025/12/22.
//

import Foundation
import SwiftUI
import PencilKit

/// 编辑器视图模型
@MainActor
class EditorViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var originalImage: UIImage
    @Published var canvasView = PKCanvasView()
    @Published var textOverlays: [TextOverlay] = []
    @Published var selectedOverlayId: UUID?

    // Tool states
    @Published var currentTool: EditorTool = .none
    @Published var brushColor: Color = .black
    @Published var brushWidth: CGFloat = 4.0
    @Published var showColorPicker = false
    @Published var showTextEditor = false

    // Crop states
    @Published var cropRect: CGRect?
    @Published var isCropping = false
    @Published var paddingAmount: CGFloat = 0 // 白边宽度（像素）

    // Error handling
    @Published var showError = false
    @Published var errorMessage: String?

    // MARK: - Private Properties
    private let fileStorageManager = FileStorageManager.shared
    private let databaseManager = DatabaseManager.shared
    private let originalSticker: Sticker?

    // MARK: - Initialization
    init(image: UIImage, sticker: Sticker? = nil) {
        self.originalImage = image
        self.originalSticker = sticker
        setupCanvasView()
    }

    // MARK: - Setup
    private func setupCanvasView() {
        canvasView.drawing = PKDrawing()
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false

        // 设置工具
        updateTool()
    }

    // MARK: - Tool Management
    func selectTool(_ tool: EditorTool) {
        currentTool = tool
        updateTool()

        // 如果选择文本工具，显示文本编辑器
        if tool == .text {
            showTextEditor = true
        }
    }

    private func updateTool() {
        switch currentTool {
        case .brush:
            let ink = PKInkingTool(.pen, color: UIColor(brushColor), width: brushWidth)
            canvasView.tool = ink
        case .eraser:
            canvasView.tool = PKEraserTool(.bitmap)
        case .none, .text, .crop:
            // 这些工具不使用 PKTool
            break
        }
    }

    func updateBrushColor(_ color: Color) {
        brushColor = color
        if currentTool == .brush {
            updateTool()
        }
    }

    func updateBrushWidth(_ width: CGFloat) {
        brushWidth = width
        if currentTool == .brush {
            updateTool()
        }
    }

    // MARK: - Text Overlay Management
    func addTextOverlay(_ text: String) {
        // 计算图片中心位置（基于原始图片尺寸）
        let imageCenter = CGPoint(
            x: originalImage.size.width / 2,
            y: originalImage.size.height / 2
        )

        let overlay = TextOverlay(
            text: text,
            position: imageCenter,
            fontSize: 32,
            color: .white
        )
        textOverlays.append(overlay)
    }

    func updateTextOverlay(_ id: UUID, text: String? = nil, position: CGPoint? = nil, fontSize: CGFloat? = nil, color: Color? = nil) {
        guard let index = textOverlays.firstIndex(where: { $0.id == id }) else { return }

        if let text = text {
            textOverlays[index].text = text
        }
        if let position = position {
            textOverlays[index].position = position
        }
        if let fontSize = fontSize {
            textOverlays[index].fontSize = fontSize
        }
        if let color = color {
            textOverlays[index].color = color
        }
    }

    func deleteTextOverlay(_ id: UUID) {
        textOverlays.removeAll { $0.id == id }
    }

    // MARK: - Crop
    func startCrop() {
        isCropping = true
        currentTool = .crop

        // 初始化裁切区域为整个图片
        cropRect = CGRect(x: 0, y: 0, width: originalImage.size.width, height: originalImage.size.height)
        paddingAmount = 0
    }

    func applyCrop() {
        guard let cropRect = cropRect else { return }

        // 如果有白边，添加白边；否则裁切图片
        if paddingAmount > 0 {
            // 添加白边
            if let paddedImage = addPadding(to: originalImage, padding: paddingAmount) {
                originalImage = paddedImage
            }
        } else {
            // 裁切图片
            if let croppedImage = cropImage(originalImage, to: cropRect) {
                originalImage = croppedImage
            }
        }

        isCropping = false
        self.cropRect = nil
        paddingAmount = 0
    }

    func cancelCrop() {
        isCropping = false
        cropRect = nil
        paddingAmount = 0
    }

    private func cropImage(_ image: UIImage, to rect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage?.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private func addPadding(to image: UIImage, padding: CGFloat) -> UIImage? {
        let newSize = CGSize(
            width: image.size.width + padding * 2,
            height: image.size.height + padding * 2
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)

        return renderer.image { context in
            // 填充白色背景
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: newSize))

            // 在中心绘制原图
            let drawPoint = CGPoint(x: padding, y: padding)
            image.draw(at: drawPoint)
        }
    }

    // MARK: - Export
    func exportImage() -> UIImage? {
        // 创建图形上下文
        let size = originalImage.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { context in
            // 1. 绘制背景图片
            originalImage.draw(at: .zero)

            // 2. 绘制 Canvas 内容
            // PKCanvasView 的绘画是在 Canvas 的 frame 尺寸下进行的
            // 我们需要将它缩放到原始图片尺寸
            let canvasFrame = canvasView.frame
            if canvasFrame.width > 0 && canvasFrame.height > 0 {
                // 计算缩放比例
                let scaleX = size.width / canvasFrame.width
                let scaleY = size.height / canvasFrame.height

                // 保存当前上下文状态
                context.cgContext.saveGState()

                // 应用缩放变换
                context.cgContext.scaleBy(x: scaleX, y: scaleY)

                // 绘制 Canvas 内容（在缩放后的坐标系中）
                let canvasRect = CGRect(origin: .zero, size: canvasFrame.size)
                let canvasImage = canvasView.drawing.image(from: canvasRect, scale: 1.0)
                canvasImage.draw(at: .zero)

                // 恢复上下文状态
                context.cgContext.restoreGState()
            }

            // 3. 绘制文本层
            for overlay in textOverlays {
                drawTextOverlay(overlay, in: context.cgContext)
            }
        }
    }

    private func drawTextOverlay(_ overlay: TextOverlay, in context: CGContext) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        // 添加描边效果
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: overlay.fontSize, weight: .bold),
            .foregroundColor: UIColor(overlay.color),
            .strokeColor: UIColor.black,
            .strokeWidth: -3.0, // 负值表示同时填充和描边
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: overlay.text, attributes: attributes)

        // 计算文本尺寸以便居中绘制
        let textSize = attributedString.size()
        let drawPoint = CGPoint(
            x: overlay.position.x - textSize.width / 2,
            y: overlay.position.y - textSize.height / 2
        )

        attributedString.draw(at: drawPoint)
    }

    // MARK: - Save
    func save() async -> Bool {
        guard let exportedImage = exportImage() else {
            showErrorMessage("导出图片失败")
            return false
        }

        do {
            // 始终保存为新表情包（副本）
            let timestamp = Date().unixTimestamp
            let filename = originalSticker?.filename ?? "edited_\(timestamp).jpg"
            let newFilename: String

            if let originalName = originalSticker?.filename.fileNameWithoutExtension {
                newFilename = "\(originalName)_edited_\(timestamp).jpg"
            } else {
                newFilename = "edited_\(timestamp).jpg"
            }

            let newSticker = try await fileStorageManager.saveImage(exportedImage, filename: newFilename)
            try await databaseManager.insertSticker(newSticker)

            print("✅ Image saved as new sticker: \(newFilename)")
            return true
        } catch {
            showErrorMessage("保存失败: \(error.localizedDescription)")
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

// MARK: - Editor Tool
enum EditorTool {
    case none
    case brush
    case eraser
    case text
    case crop
}

// MARK: - Text Overlay Model
struct TextOverlay: Identifiable {
    let id = UUID()
    var text: String
    var position: CGPoint
    var fontSize: CGFloat
    var color: Color
    var rotation: Double = 0
    var scale: CGFloat = 1.0
}
