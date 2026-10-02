#if canImport(UIKit)
import SwiftUI
import VisionKit
import Domain

public struct BarcodeScannerView: UIViewControllerRepresentable {
    public let onFound: (ISBN) -> Void

    public init(onFound: @escaping (ISBN) -> Void) {
        self.onFound = onFound
    }

    public func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    public func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(onFound: onFound)
    }

    public final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onFound: (ISBN) -> Void
        private var hasFound = false

        public init(onFound: @escaping (ISBN) -> Void) {
            self.onFound = onFound
        }

        public func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !hasFound else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue, let isbn = ISBN(payload) {
                    hasFound = true
                    onFound(isbn)
                    break
                }
            }
        }
    }
}

#endif
