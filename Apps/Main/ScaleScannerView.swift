//
//  ScaleScannerView.swift
//  Scale
//
//  Created by Jonathan Groberg on 4/4/26.
//

import SwiftUI
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

struct ScaleScannerView: View {
    let onWeightScanned: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appTint") private var appTint = AppTint.defaultValue.rawValue

    @State private var scannedWeight: Double?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var cameraPermissionGranted = false

    private var tintColor: Color {
        (AppTint(rawValue: appTint) ?? .defaultValue).color
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if cameraPermissionGranted {
                    CameraPreviewRepresentable(onFrameCaptured: processFrame)
                        .ignoresSafeArea()
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "camera.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Camera access is required to scan your scale.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }

                // Overlay UI
                VStack {
                    Spacer()

                    // Scanning reticle
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(0.6), lineWidth: 2)
                        .frame(width: 260, height: 100)
                        .overlay {
                            if isProcessing {
                                ProgressView()
                                    .tint(.white)
                            }
                        }

                    Text("Point at your scale display")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.top, 8)

                    Spacer()

                    // Result area
                    if let weight = scannedWeight {
                        VStack(spacing: 12) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(String(format: "%.1f", weight))
                                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("lbs")
                                    .font(.title3.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.7))
                            }

                            Button {
                                Haptics.success()
                                onWeightScanned(weight)
                                dismiss()
                            } label: {
                                Text("Use This Weight")
                                    .font(.headline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(tintColor)
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.bottom, 8)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .white.opacity(0.3))
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                checkCameraPermission()
            }
        }
    }

    // MARK: - Camera Permission

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionGranted = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    cameraPermissionGranted = granted
                }
            }
        default:
            cameraPermissionGranted = false
        }
    }

    // MARK: - Frame Processing (Path 1: Core Image Pre-Processing)

    private func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard !isProcessing else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        // 1. Crop to center region (where the scale display likely is)
        let fullExtent = ciImage.extent
        let cropWidth = fullExtent.width * 0.6
        let cropHeight = fullExtent.height * 0.25
        let cropOrigin = CGPoint(
            x: fullExtent.midX - cropWidth / 2,
            y: fullExtent.midY - cropHeight / 2
        )
        let cropRect = CGRect(origin: cropOrigin, size: CGSize(width: cropWidth, height: cropHeight))
        let cropped = ciImage.cropped(to: cropRect)

        // 2. Convert to grayscale
        let grayscale = cropped.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.0,
            kCIInputContrastKey: 1.5
        ])

        // 3. Threshold to black & white (using CIColorClamp + CIColorMatrix for a threshold effect)
        let thresholded = grayscale.applyingFilter("CIColorThreshold", parameters: [
            "inputThreshold": 0.5
        ])

        // 4. Morphological dilation to connect segment gaps
        let dilated = thresholded.applyingFilter("CIMorphologyMaximum", parameters: [
            kCIInputRadiusKey: 3.0
        ])

        // Run Vision OCR on the pre-processed image
        recognizeText(in: dilated)
    }

    func recognizeText(in ciImage: CIImage) {
        Task { @MainActor in
            isProcessing = true
        }

        let request = VNRecognizeTextRequest { request, error in
            defer {
                Task { @MainActor in
                    isProcessing = false
                }
            }

            guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                return
            }

            // Collect all recognized text candidates
            let candidates = observations.compactMap { observation in
                observation.topCandidates(3)
            }.flatMap { $0 }

            // Try to find a valid weight reading
            for candidate in candidates {
                if let weight = WeightCalculations.parseScaleReading(candidate.string) {
                    Task { @MainActor in
                        withAnimation(.snappy) {
                            scannedWeight = weight
                            errorMessage = nil
                        }
                        Haptics.impact(.medium)
                    }
                    return
                }
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.revision = VNRecognizeTextRequestRevision3

        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            Task { @MainActor in
                isProcessing = false
            }
        }
    }
}

// MARK: - Camera Preview

private struct CameraPreviewRepresentable: UIViewControllerRepresentable {
    let onFrameCaptured: (CMSampleBuffer) -> Void

    func makeUIViewController(context: Context) -> CameraPreviewController {
        CameraPreviewController(onFrameCaptured: onFrameCaptured)
    }

    func updateUIViewController(_ uiViewController: CameraPreviewController, context: Context) {}
}

final class CameraPreviewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.scale.scanner", qos: .userInitiated)
    private let onFrameCaptured: (CMSampleBuffer) -> Void
    private var previewLayer: AVCaptureVideoPreviewLayer?

    /// Throttle frame processing — process roughly 2 frames per second
    private var lastProcessedTime: CFTimeInterval = 0
    private let processInterval: CFTimeInterval = 0.5

    init(onFrameCaptured: @escaping (CMSampleBuffer) -> Void) {
        self.onFrameCaptured = onFrameCaptured
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupCamera() {
        captureSession.sessionPreset = .high

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else { return }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true

        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        // Enable auto-focus for close-up scale reading
        if camera.isFocusModeSupported(.continuousAutoFocus) {
            try? camera.lockForConfiguration()
            camera.focusMode = .continuousAutoFocus
            if camera.isAutoFocusRangeRestrictionSupported {
                camera.autoFocusRangeRestriction = .near
            }
            camera.unlockForConfiguration()
        }

        let preview = AVCaptureVideoPreviewLayer(session: captureSession)
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        previewLayer = preview

        DispatchQueue.global(qos: .userInitiated).async { [captureSession] in
            captureSession.startRunning()
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = CACurrentMediaTime()
        guard now - lastProcessedTime >= processInterval else { return }
        lastProcessedTime = now
        onFrameCaptured(sampleBuffer)
    }

    deinit {
        captureSession.stopRunning()
    }
}
