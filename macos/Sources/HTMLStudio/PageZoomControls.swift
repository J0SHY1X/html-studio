import SwiftUI

struct PageZoomControls: View {
    @ObservedObject var controller: DesignEditorController

    var body: some View {
        HStack(spacing: 2) {
            Button { controller.setZoom(controller.zoomPercent - 10) } label: {
                Image(systemName: "minus").frame(width: 24, height: 20)
            }
            .disabled(controller.zoomPercent <= 50)
            .help("缩小页面")
            .accessibilityLabel("缩小页面")

            Button { controller.setZoom(100) } label: {
                Text("\(controller.zoomPercent)%")
                    .monospacedDigit().frame(width: 44, height: 20)
            }
            .help("页面显示比例；点击恢复 100%")
            .accessibilityLabel("页面显示比例 \(controller.zoomPercent)%，点击恢复 100%")

            Button { controller.setZoom(controller.zoomPercent + 10) } label: {
                Image(systemName: "plus").frame(width: 24, height: 20)
            }
            .disabled(controller.zoomPercent >= 200)
            .help("放大页面")
            .accessibilityLabel("放大页面")
        }
        .buttonStyle(.borderless)
        .controlSize(.mini)
        .accessibilityElement(children: .contain)
    }
}
