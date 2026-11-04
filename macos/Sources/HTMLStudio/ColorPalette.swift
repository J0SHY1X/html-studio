import AppKit
import SwiftUI

struct EditorPaletteColor: Identifiable, Hashable {
    let name: String
    let hex: String

    var id: String { hex }
}

enum EditorColorPalette {
    static let text: [EditorPaletteColor] = [
        .init(name: "黑色", hex: "#111827"),
        .init(name: "深灰", hex: "#4B5563"),
        .init(name: "红色", hex: "#DC2626"),
        .init(name: "橙色", hex: "#EA580C"),
        .init(name: "金色", hex: "#CA8A04"),
        .init(name: "绿色", hex: "#15803D"),
        .init(name: "蓝色", hex: "#2563EB"),
        .init(name: "紫色", hex: "#7C3AED"),
        .init(name: "白色", hex: "#FFFFFF")
    ]

    static let surface: [EditorPaletteColor] = [
        .init(name: "白色", hex: "#FFFFFF"),
        .init(name: "浅灰", hex: "#F3F4F6"),
        .init(name: "淡黄", hex: "#FEF3C7"),
        .init(name: "浅绿", hex: "#DCFCE7"),
        .init(name: "浅蓝", hex: "#DBEAFE"),
        .init(name: "淡紫", hex: "#F3E8FF"),
        .init(name: "淡橙", hex: "#FFEDD5"),
        .init(name: "淡红", hex: "#FEE2E2")
    ]

    static let highlighters: [EditorPaletteColor] = [
        .init(name: "淡黄", hex: "#FFF3A3"),
        .init(name: "浅绿", hex: "#CFF7D3"),
        .init(name: "淡紫", hex: "#E7D7FF"),
        .init(name: "品红", hex: "#FFB3DE"),
        .init(name: "浅蓝", hex: "#BFE8FF"),
        .init(name: "淡橙", hex: "#FFD3A8")
    ]
}

struct SimpleColorPaletteButton: View {
    let title: String
    let systemImage: String
    let paletteID: String
    let colors: [EditorPaletteColor]
    let initialColor: String
    var clearTitle: String?
    let onApply: (String?) -> Void

    @State private var isPresented = false
    @State private var selectedColor: String
    @State private var customColors: [String] = []
    @StateObject private var colorPanel = EditorColorPanelRelay()

    init(
        title: String,
        systemImage: String,
        paletteID: String,
        colors: [EditorPaletteColor],
        initialColor: String,
        clearTitle: String? = nil,
        onApply: @escaping (String?) -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.paletteID = paletteID
        self.colors = colors
        self.initialColor = initialColor
        self.clearTitle = clearTitle
        self.onApply = onApply
        _selectedColor = State(initialValue: initialColor)
    }

    var body: some View {
        Button {
            customColors = EditorCustomColors.values(for: paletteID)
            isPresented.toggle()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                Text(title)
                swatch(selectedColor)
            }
        }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.headline)
                Text("点选后立即应用；可继续尝试其他颜色。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(34), spacing: 8), count: 5),
                    spacing: 8
                ) {
                    ForEach(colors) { color in
                        colorButton(color.hex, help: color.name)
                    }
                    ForEach(customColors, id: \.self) { hex in
                        colorButton(hex, help: "自定义颜色 \(hex)")
                    }
                }

                Divider()

                HStack {
                    if let clearTitle {
                        Button(clearTitle) {
                            selectedColor = "transparent"
                            onApply(nil)
                        }
                    }
                    Button("更多颜色…") {
                        colorPanel.show(initialHex: selectedColor) { hex in
                            selectedColor = hex
                            EditorCustomColors.add(hex, for: paletteID)
                            customColors = EditorCustomColors.values(for: paletteID)
                            onApply(hex)
                        }
                    }
                    Spacer()
                    Button("完成") { isPresented = false }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(14)
            .frame(width: 250)
        }
        .help("打开\(title)标准色面板")
    }

    private func colorButton(_ hex: String, help: String) -> some View {
        Button {
            selectedColor = hex
            onApply(hex)
        } label: {
            swatch(hex)
                .frame(width: 28, height: 28)
                .overlay {
                    if selectedColor.caseInsensitiveCompare(hex) == .orderedSame {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(contrastColor(for: hex))
                    }
                }
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func swatch(_ hex: String) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(hexString: hex) ?? .clear)
            .frame(width: 18, height: 14)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.45)))
    }

    private func contrastColor(for hex: String) -> Color {
        guard let color = NSColor(hexString: hex)?.usingColorSpace(.sRGB) else { return .black }
        let brightness = color.redComponent * 0.299 + color.greenComponent * 0.587 + color.blueComponent * 0.114
        return brightness > 0.62 ? .black : .white
    }
}

private enum EditorCustomColors {
    static func values(for paletteID: String) -> [String] {
        UserDefaults.standard.stringArray(forKey: key(paletteID)) ?? []
    }

    static func add(_ value: String, for paletteID: String) {
        let normalized = value.uppercased()
        var values = values(for: paletteID)
        values.removeAll { $0.caseInsensitiveCompare(normalized) == .orderedSame }
        values.insert(normalized, at: 0)
        UserDefaults.standard.set(Array(values.prefix(10)), forKey: key(paletteID))
    }

    private static func key(_ paletteID: String) -> String {
        "HTMLStudio.customColors.\(paletteID)"
    }
}

@MainActor
private final class EditorColorPanelRelay: NSObject, ObservableObject {
    private var onChange: ((String) -> Void)?

    func show(initialHex: String, onChange: @escaping (String) -> Void) {
        self.onChange = onChange
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        if let color = NSColor(hexString: initialHex) {
            panel.color = color
        }
        panel.setTarget(self)
        panel.setAction(#selector(colorChanged(_:)))
        panel.orderFront(nil)
    }

    @objc private func colorChanged(_ sender: NSColorPanel) {
        guard let color = sender.color.usingColorSpace(.sRGB) else { return }
        onChange?(color.hexRGB)
    }
}

private extension NSColor {
    convenience init?(hexString: String) {
        let value = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard value.count == 6, let number = Int(value, radix: 16) else { return nil }
        self.init(
            srgbRed: CGFloat((number >> 16) & 0xFF) / 255,
            green: CGFloat((number >> 8) & 0xFF) / 255,
            blue: CGFloat(number & 0xFF) / 255,
            alpha: 1
        )
    }

    var hexRGB: String {
        guard let color = usingColorSpace(.sRGB) else { return "#000000" }
        return String(
            format: "#%02X%02X%02X",
            Int(round(color.redComponent * 255)),
            Int(round(color.greenComponent * 255)),
            Int(round(color.blueComponent * 255))
        )
    }
}

private extension Color {
    init?(hexString: String) {
        guard let color = NSColor(hexString: hexString) else { return nil }
        self.init(nsColor: color)
    }
}
