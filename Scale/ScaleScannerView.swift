//
//  ScaleScannerView.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/15/26.
//

import SwiftUI
import VisionKit

/// A camera view that uses Live Text to recognize the weight displayed on a physical scale.
struct ScaleScannerView: View {
    @Environment(\.dismiss) private var dismiss
    var onWeightScanned: (Double) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                DataScannerRepresentable(onWeightScanned: { weight in
                    onWeightScanned(weight)
                    dismiss()
                })
                .ignoresSafeArea()
            } else {
                unavailableView
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
            }
            .padding(20)
        }
        .background(Color.black)
    }

    private var unavailableView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Camera Scanning Unavailable")
                .font(.title3.weight(.semibold))
            Text("This device doesn't support Live Text scanning. Please enter your weight manually.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

// MARK: - DataScannerViewController Wrapper

private struct DataScannerRepresentable: UIViewControllerRepresentable {
    var onWeightScanned: (Double) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onWeightScanned: onWeightScanned)
    }

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onWeightScanned: (Double) -> Void

        /// Matches plausible weight values: 1-3 digits, optional decimal with up to 1 digit.
        private let weightPattern = /^\d{1,3}(\.\d{0,1})?$/

        init(onWeightScanned: @escaping (Double) -> Void) {
            self.onWeightScanned = onWeightScanned
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            guard case .text(let text) = item else { return }

            let transcript = text.transcript.trimmingCharacters(in: .whitespaces)
            if transcript.wholeMatch(of: weightPattern) != nil,
               let weight = Double(transcript), weight > 0 {
                onWeightScanned(weight)
            }
        }

        func dataScannerDidBecomeAvailable(_ dataScanner: DataScannerViewController) {
            try? dataScanner.startScanning()
        }

        func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
            dataScanner.stopScanning()
        }
    }
}
