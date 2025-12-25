//
//  EditorView.swift
//  stickers-gen
//
//  Created on 2025/12/22.
//

import SwiftUI
import PencilKit

/// 图片编辑器视图
struct EditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EditorViewModel

    init(image: UIImage, sticker: Sticker? = nil) {
        _viewModel = StateObject(wrappedValue: EditorViewModel(image: image, sticker: sticker))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 主编辑区域
                EditorCanvasView(viewModel: viewModel)

                // 工具栏
                VStack {
                    Spacer()

                    EditorToolbar(viewModel: viewModel)
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                }
            }
            .navigationTitle("编辑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        Task {
                            let success = await viewModel.save()
                            if success {
                                dismiss()
                            }
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("错误", isPresented: $viewModel.showError) {
                Button("确定", role: .cancel) {
                    viewModel.clearError()
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            .sheet(isPresented: $viewModel.showColorPicker) {
                ColorPickerSheet(selectedColor: $viewModel.brushColor, onSelect: { color in
                    viewModel.updateBrushColor(color)
                })
            }
            .sheet(isPresented: $viewModel.showTextEditor) {
                TextEditorSheet(onAdd: { text in
                    viewModel.addTextOverlay(text)
                })
            }
            .sheet(isPresented: $viewModel.showTextColorPicker) {
                ColorPickerSheet(selectedColor: $viewModel.textColor, onSelect: { color in
                    viewModel.updateTextColor(color)
                })
            }
        }
    }
}

// MARK: - Editor Canvas View
struct EditorCanvasView: View {
    @ObservedObject var viewModel: EditorViewModel

    var body: some View {
        GeometryReader { geometry in
            let displaySize = calculateImageSize(
                imageSize: viewModel.originalImage.size,
                containerSize: geometry.size
            )
            let scaleX = viewModel.originalImage.size.width / displaySize.width
            let scaleY = viewModel.originalImage.size.height / displaySize.height
            let offsetX = (geometry.size.width - displaySize.width) / 2
            let offsetY = (geometry.size.height - displaySize.height) / 2

            ZStack {
                // 灰色背景（编辑区域外）
                Color(.systemGray5)
                    .ignoresSafeArea()

                // 背景图片
                Image(uiImage: viewModel.originalImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // 点击空白区域：取消所有工具和文本选中
                        viewModel.deselectAllTools()
                    }

                // Canvas 绘画层
                CanvasView(canvasView: viewModel.canvasView, viewModel: viewModel)
                    .frame(width: displaySize.width, height: displaySize.height)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                // 文本叠加层
                textOverlaysView(
                    scaleX: scaleX,
                    scaleY: scaleY,
                    offsetX: offsetX,
                    offsetY: offsetY,
                    displaySize: displaySize
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    @ViewBuilder
    private func textOverlaysView(
        scaleX: CGFloat,
        scaleY: CGFloat,
        offsetX: CGFloat,
        offsetY: CGFloat,
        displaySize: CGSize
    ) -> some View {
        ForEach(viewModel.textOverlays) { overlay in
            let screenPosition = CGPoint(
                x: overlay.position.x / scaleX + offsetX,
                y: overlay.position.y / scaleY + offsetY
            )
            let displayFontSize = overlay.fontSize / scaleX

            DraggableTextView(
                overlay: overlay,
                displayPosition: screenPosition,
                displayFontSize: displayFontSize,
                imageSize: displaySize,
                imageOffset: CGPoint(x: offsetX, y: offsetY),
                isSelected: viewModel.selectedOverlayId == overlay.id,
                onTap: {
                    viewModel.selectedOverlayId = overlay.id
                    // 选中文本时，切换到文本工具
                    viewModel.currentTool = .text
                },
                onDrag: { screenPos in
                    let imagePosition = CGPoint(
                        x: (screenPos.x - offsetX) * scaleX,
                        y: (screenPos.y - offsetY) * scaleY
                    )
                    viewModel.updateTextOverlay(overlay.id, position: imagePosition)
                }
            )
        }
    }

    private func calculateImageSize(imageSize: CGSize, containerSize: CGSize) -> CGSize {
        let aspectRatio = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height

        if aspectRatio > containerAspect {
            // 图片更宽
            let width = containerSize.width
            let height = width / aspectRatio
            return CGSize(width: width, height: height)
        } else {
            // 图片更高
            let height = containerSize.height
            let width = height * aspectRatio
            return CGSize(width: width, height: height)
        }
    }
}

// MARK: - Canvas View (UIViewRepresentable)
struct CanvasView: UIViewRepresentable {
    let canvasView: PKCanvasView
    @ObservedObject var viewModel: EditorViewModel

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.delegate = context.coordinator

        // 允许手指和Apple Pencil绘画
        canvasView.drawingPolicy = .anyInput

        // 启用用户交互
        canvasView.isUserInteractionEnabled = true

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // 更新工具
        uiView.tool = canvasView.tool
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        let viewModel: EditorViewModel

        init(viewModel: EditorViewModel) {
            self.viewModel = viewModel
        }
    }
}

// MARK: - Editor Toolbar
struct EditorToolbar: View {
    @ObservedObject var viewModel: EditorViewModel

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                // 左侧工具选择
                HStack(spacing: 20) {
                    ToolButton(
                        icon: "pencil.tip",
                        isSelected: viewModel.currentTool == .brush,
                        action: { viewModel.selectTool(.brush) }
                    )

                    ToolButton(
                        icon: "eraser.fill",
                        isSelected: viewModel.currentTool == .eraser,
                        action: { viewModel.selectTool(.eraser) }
                    )

                    ToolButton(
                        icon: "textformat",
                        isSelected: viewModel.currentTool == .text,
                        action: { viewModel.selectTool(.text) }
                    )

                    // 删除选中的文本按钮
                    if viewModel.selectedOverlayId != nil {
                        Button(action: {
                            if let selectedId = viewModel.selectedOverlayId {
                                viewModel.deleteTextOverlay(selectedId)
                            }
                        }) {
                            Image(systemName: "trash")
                                .font(.title3)
                                .foregroundColor(.red)
                                .frame(width: 44, height: 44)
                        }
                    }
                }

                Spacer()

                // 右侧白边按钮
                Button(action: {
                    viewModel.toggleBottomPadding()
                }) {
                    Image(systemName: "rectangle.bottomthird.inset.filled")
                        .font(.title3)
                        .foregroundColor(viewModel.hasBottomPadding ? .white : .primary)
                        .frame(width: 44, height: 44)
                        .background(viewModel.hasBottomPadding ? Color.blue : Color.clear)
                        .cornerRadius(8)
                }
            }

            // 画笔工具选项
            if viewModel.currentTool == .brush {
                BrushOptionsView(viewModel: viewModel)
            }

            // 文本编辑选项（当有选中的文本时显示）
            if let selectedId = viewModel.selectedOverlayId,
               let overlay = viewModel.textOverlays.first(where: { $0.id == selectedId }) {
                TextEditOptionsView(viewModel: viewModel, overlay: overlay)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

// MARK: - Tool Button
struct ToolButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isSelected ? .white : .primary)
                .frame(width: 44, height: 44)
                .background(isSelected ? Color.blue : Color.clear)
                .cornerRadius(8)
        }
    }
}

// MARK: - Brush Options View
struct BrushOptionsView: View {
    @ObservedObject var viewModel: EditorViewModel

    var body: some View {
        VStack(spacing: 8) {
            // 颜色选择
            HStack {
                Text("颜色")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    viewModel.showColorPicker = true
                }) {
                    Circle()
                        .fill(viewModel.brushColor)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(Color.gray, lineWidth: 1)
                        )
                }
            }

            // 粗细滑块
            HStack {
                Text("粗细")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(value: $viewModel.brushWidth, in: 2...32, step: 7.5) {
                    Text("粗细")
                } minimumValueLabel: {
                    Text("细")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } maximumValueLabel: {
                    Text("粗")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .onChange(of: viewModel.brushWidth) { _, newValue in
                    viewModel.updateBrushWidth(newValue)
                }
                .frame(maxWidth: 200)
            }
        }
    }
}

// MARK: - Text Edit Options View
struct TextEditOptionsView: View {
    @ObservedObject var viewModel: EditorViewModel
    let overlay: TextOverlay

    var body: some View {
        VStack(spacing: 8) {
            // 字体大小
            HStack {
                Text("大小")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(value: Binding(
                    get: { overlay.fontSize },
                    set: { newValue in
                        viewModel.updateTextOverlay(overlay.id, fontSize: newValue)
                    }
                ), in: 16...80, step: 4) {
                    Text("大小")
                } minimumValueLabel: {
                    Text("小")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } maximumValueLabel: {
                    Text("大")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: 200)

                Text("\(Int(overlay.fontSize))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 30)
            }

            // 颜色选择
            HStack {
                Text("颜色")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    viewModel.showTextColorPicker = true
                }) {
                    Circle()
                        .fill(overlay.color)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(Color.gray, lineWidth: 1)
                        )
                }
            }
        }
    }
}

// MARK: - Color Picker Sheet
struct ColorPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedColor: Color
    var onSelect: (Color) -> Void

    let presetColors: [Color] = [
        .black, .white, .red, .blue, .green, .yellow, .orange, .purple, .pink, .brown
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 预设颜色
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                    ForEach(presetColors, id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Circle()
                                    .stroke(selectedColor == color ? Color.blue : Color.gray, lineWidth: 3)
                            )
                            .onTapGesture {
                                selectedColor = color
                                onSelect(color)
                            }
                    }
                }
                .padding()

                // 自定义颜色选择器
                ColorPicker("自定义颜色", selection: $selectedColor)
                    .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("选择颜色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        onSelect(selectedColor)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Text Editor Sheet
struct TextEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    var onAdd: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $text)
                    .font(.title2)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("添加文本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("添加") {
                        if !text.isEmpty {
                            onAdd(text)
                            dismiss()
                        }
                    }
                    .disabled(text.isEmpty)
                }
            }
        }
    }
}

// MARK: - Draggable Text View
struct DraggableTextView: View {
    let overlay: TextOverlay
    let displayPosition: CGPoint // 屏幕坐标
    let displayFontSize: CGFloat // 屏幕显示的字体大小（已缩放）
    let imageSize: CGSize // 图片在屏幕上的显示尺寸
    let imageOffset: CGPoint // 图片在屏幕上的偏移
    let isSelected: Bool
    let onTap: () -> Void
    let onDrag: (CGPoint) -> Void // 传递屏幕坐标

    @State private var dragOffset: CGSize = .zero
    @State private var textSize: CGSize = .zero

    var body: some View {
        Text(overlay.text)
            .font(.system(size: displayFontSize, weight: .bold))
            .foregroundColor(overlay.color)
            .shadow(color: .black, radius: 2, x: 0, y: 0)
            .shadow(color: .black, radius: 2, x: 0, y: 0)
            .padding(8)
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(key: TextSizePreferenceKey.self, value: geometry.size)
                }
            )
            .onPreferenceChange(TextSizePreferenceKey.self) { size in
                textSize = size
            }
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(isSelected ? 0.3 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .position(
                x: displayPosition.x + dragOffset.width,
                y: displayPosition.y + dragOffset.height
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        // 计算新位置（屏幕坐标）
                        var newX = displayPosition.x + value.translation.width
                        var newY = displayPosition.y + value.translation.height

                        // 限制在图片边界内，考虑文本框的实际尺寸
                        let halfWidth = textSize.width / 2
                        let halfHeight = textSize.height / 2

                        let minX = imageOffset.x + halfWidth
                        let maxX = imageOffset.x + imageSize.width - halfWidth
                        let minY = imageOffset.y + halfHeight
                        let maxY = imageOffset.y + imageSize.height - halfHeight

                        newX = max(minX, min(maxX, newX))
                        newY = max(minY, min(maxY, newY))

                        let newScreenPosition = CGPoint(x: newX, y: newY)
                        onDrag(newScreenPosition)
                        dragOffset = .zero
                    }
            )
            .onTapGesture {
                onTap()
            }
    }
}

// MARK: - Text Size Preference Key
private struct TextSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

#Preview {
    EditorView(image: UIImage(systemName: "photo")!)
}
