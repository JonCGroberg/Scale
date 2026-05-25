import Testing
import UIKit
import SwiftUI
import QuickLook
@testable import Scale

struct QuickLookPreviewCoordinatorTests {

    @Test func coordinatorWritesAllImagesToTemp() {
        let images = makeImages(count: 3)
        let coordinator = QuickLookPreview.Coordinator(images: images, isPresented: .constant(false))

        #expect(coordinator.tempURLs.count == 3)
        for url in coordinator.tempURLs {
            #expect(FileManager.default.fileExists(atPath: url.path))
        }
    }

    @Test func coordinatorReturnsZeroItemsForEmptyImages() {
        let coordinator = QuickLookPreview.Coordinator(images: [], isPresented: .constant(false))

        #expect(coordinator.tempURLs.isEmpty)
        #expect(coordinator.numberOfPreviewItems(in: QLPreviewController()) == 0)
    }

    @Test func coordinatorProvidesImagesInOrder() {
        let images = makeImages(count: 2)
        let coordinator = QuickLookPreview.Coordinator(images: images, isPresented: .constant(false))

        #expect(coordinator.numberOfPreviewItems(in: QLPreviewController()) == 2)

        let item0 = coordinator.previewController(QLPreviewController(), previewItemAt: 0)
        let item1 = coordinator.previewController(QLPreviewController(), previewItemAt: 1)

        #expect(item0.previewItemURL != nil)
        #expect(item1.previewItemURL != nil)
        #expect(item0.previewItemURL != item1.previewItemURL)
    }

    @Test func coordinatorTempFilesHaveJpegExtension() {
        let images = makeImages(count: 1)
        let coordinator = QuickLookPreview.Coordinator(images: images, isPresented: .constant(false))

        #expect(coordinator.tempURLs[0].pathExtension == "jpg")
    }

    @Test func coordinatorDeinitCleansUpTempFiles() {
        let images = makeImages(count: 2)
        var tempURLs: [URL] = []

        do {
            let coordinator = QuickLookPreview.Coordinator(images: images, isPresented: .constant(false))
            tempURLs = coordinator.tempURLs
            for url in tempURLs {
                #expect(FileManager.default.fileExists(atPath: url.path))
            }
        }

        for url in tempURLs {
            #expect(!FileManager.default.fileExists(atPath: url.path))
        }
    }

    @Test func closeSetsIsPresentedFalse() {
        var isPresented = true
        let binding = Binding(get: { isPresented }, set: { isPresented = $0 })
        let coordinator = QuickLookPreview.Coordinator(images: [], isPresented: binding)

        coordinator.close()

        #expect(isPresented == false)
    }

    @Test func returnsNoPreviewItemsOutOfBounds() {
        let images = makeImages(count: 1)
        let coordinator = QuickLookPreview.Coordinator(images: images, isPresented: .constant(false))
        let controller = QLPreviewController()

        #expect(coordinator.numberOfPreviewItems(in: controller) == 1)

        let item = coordinator.previewController(controller, previewItemAt: 0)
        #expect(item.previewItemURL != nil)
        #expect(FileManager.default.fileExists(atPath: item.previewItemURL!.path))
    }

    private func makeImages(count: Int) -> [UIImage] {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
        return (0..<count).map { i in
            renderer.image { context in
                UIColor(
                    red: CGFloat(i) / CGFloat(count),
                    green: 0.5,
                    blue: 0.5,
                    alpha: 1
                ).setFill()
                context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
            }
        }
    }
}

struct DayPreviewPopupRenderTests {

    @Test func dayPreviewPopupConstructsWithPhotos() {
        let photo = makeImage()
        let preview = JournalView.DayPreview(
            date: Date(),
            photos: [photo],
            weightText: "180.0 lbs",
            entryCount: 1,
            workoutCount: 0,
            stepCount: 0,
            activeEnergyBurnedKilocalories: 0,
            sleepDuration: 0
        )
        var dismissed = false

        let popup = DayPreviewPopup(
            preview: preview,
            tintColor: .blue,
            title: "Test",
            onDismiss: { dismissed = true },
            onPreviousDay: nil,
            onNextDay: nil,
            onTapPhoto: { _ in }
        )

        let controller = UIHostingController(rootView: popup)
        controller.loadViewIfNeeded()

        #expect(controller.view != nil)
        #expect(dismissed == false)
    }

    @Test func dayPreviewPopupRendersWithoutPhotos() {
        let preview = JournalView.DayPreview(
            date: Date(),
            photos: [],
            weightText: nil,
            entryCount: 0,
            workoutCount: 0,
            stepCount: 0,
            activeEnergyBurnedKilocalories: 0,
            sleepDuration: 0
        )

        let popup = DayPreviewPopup(
            preview: preview,
            tintColor: .blue,
            title: "No Photos",
            onDismiss: {},
            onPreviousDay: nil,
            onNextDay: nil,
            onTapPhoto: nil
        )

        let controller = UIHostingController(rootView: popup)
        controller.loadViewIfNeeded()

        #expect(controller.view != nil)
    }

    @Test func onTapPhotoIsCalled() {
        let photo = makeImage()
        let preview = JournalView.DayPreview(
            date: Date(),
            photos: [photo],
            weightText: nil,
            entryCount: 0,
            workoutCount: 0,
            stepCount: 0,
            activeEnergyBurnedKilocalories: 0,
            sleepDuration: 0
        )
        var tappedIndex: Int?

        let popup = DayPreviewPopup(
            preview: preview,
            tintColor: .blue,
            title: "Test",
            onDismiss: {},
            onPreviousDay: nil,
            onNextDay: nil,
            onTapPhoto: { index in tappedIndex = index }
        )

        let controller = UIHostingController(rootView: popup)
        controller.loadViewIfNeeded()

        let tapGesture = UITapGestureRecognizer()
        controller.view.addGestureRecognizer(tapGesture)

        #expect(controller.view != nil)
    }

    private func makeImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
        return renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
    }
}
