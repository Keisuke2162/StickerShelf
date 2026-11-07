#if canImport(UIKit)
import SwiftUI
import VisionKit

/// VisionKit の `VNDocumentCameraViewController` を SwiftUI にラップする。
/// 本の表紙を撮影すると、四角検出・遠近補正・エッジ強調まで自動で行われたページ画像が返る。
/// 最初の 1 ページだけを `onCapture` に渡し、残りは破棄する（書影は 1 枚だけ採用する運用）。
public struct DocumentScannerView: UIViewControllerRepresentable {
    public let onCapture: (UIImage) -> Void
    public let onCancel: () -> Void

    public init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
        self.onCapture = onCapture
        self.onCancel = onCancel
    }

    public func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    public func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    public final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onCapture: (UIImage) -> Void
        let onCancel: () -> Void

        public init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            guard scan.pageCount > 0 else { onCancel(); return }
            onCapture(scan.imageOfPage(at: 0))
        }

        public func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }

        public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onCancel()
        }
    }
}

#endif
