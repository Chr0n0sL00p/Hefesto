//
//  ARQuickLookPresenter.swift
//  Hefesto - Integración Nativa con Apple AR QuickLook
//

import SwiftUI
import QuickLook

public struct ARQuickLookPresenter: UIViewControllerRepresentable {
    public let fileUrl: URL

    public init(fileUrl: URL) {
        self.fileUrl = fileUrl
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIViewController(context: Context) -> UINavigationController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        let nav = UINavigationController(rootViewController: controller)
        return nav
    }

    public func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    public class Coordinator: NSObject, QLPreviewControllerDataSource {
        let parent: ARQuickLookPresenter

        init(_ parent: ARQuickLookPresenter) {
            self.parent = parent
        }

        public func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }

        public func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return parent.fileUrl as QLPreviewItem
        }
    }
}
