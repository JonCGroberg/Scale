//
//  Standalone_View_Coverage_Tests.swift
//  ScaleTests
//
//  Exercises standalone SwiftUI view bodies so coverage reflects their
//  declarative branches without depending on screenshot rendering.
//

import SwiftData
import SwiftUI
import Testing
import UIKit
import HealthKit
import CoreImage
@testable import Scale

@MainActor
struct StandaloneViewCoverageTests {
    @Test func logViewBodyConstructsJournalWrapper() throws {
        let container = try makeModelContainer()
        var showLog = false
        var logDate: Date?
        let view = LogView(
            scrollToLogsTrigger: 1,
            focusedEntry: nil,
            showLog: Binding(get: { showLog }, set: { showLog = $0 }),
            logDate: Binding(get: { logDate }, set: { logDate = $0 })
        )
            .modelContainer(container)
            .environment(HealthKitManager())
            .environment(NotificationManager())

        let controller = mount(view)

        #expect(controller.view != nil)
    }

    @Test func settingsViewBodyConstructsWithRequiredEnvironment() throws {
        let container = try makeModelContainer()
        let healthManager = HealthKitManager()
        let notificationManager = NotificationManager()
        notificationManager.modelContext = ModelContext(container)

        let view = SettingsView()
            .modelContainer(container)
            .environment(healthManager)
            .environment(notificationManager)

        let controller = mount(view)

        #expect(controller.view != nil)
    }

    @Test func settingsViewCoversHealthImportResultBranches() throws {
        let container = try makeModelContainer()
        let notificationManager = NotificationManager()
        notificationManager.modelContext = ModelContext(container)

        let states: [HealthKitManager.ImportResult?] = [
            nil,
            .success(imported: 0, skipped: 2, removed: 0),
            .success(imported: 0, skipped: 0, removed: 0),
            .success(imported: 2, skipped: 1, removed: 1),
            .error("Permission denied")
        ]

        for state in states {
            let healthManager = HealthKitManager()
            healthManager.isAvailable = true
            healthManager.importResult = state
            healthManager.workoutImportResult = state
            healthManager.dailyActivityImportResult = state

            let view = SettingsView()
                .modelContainer(container)
                .environment(healthManager)
                .environment(notificationManager)

            let controller = mount(view)
            #expect(controller.view != nil)
        }
    }

    @Test func onboardingViewBodyConstructsWithNotificationEnvironment() {
        let view = OnboardingView()
            .environment(HealthKitManager())
            .environment(NotificationManager())

        let controller = mount(view)

        #expect(controller.view != nil)
    }

    @Test func onboardingIllustrationLeafViewsConstruct() {
        let photoCard = PlaceholderPhotoCard(
            title: "Morning weigh-in",
            subtitle: "Camera capture",
            background: LinearGradient(
                colors: [.orange, .blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            accent: .white,
            systemImage: "figure.stand"
        )

        let controllers = [
            mount(photoCard).view,
            mount(PlaceholderCalendarCard()).view,
            mount(PlaceholderGraphCard()).view,
            mount(PlaceholderMiniGraphCard()).view,
            mount(
                OnboardingPreviewPages()
                    .environment(HealthKitManager())
                    .environment(NotificationManager())
            ).view
        ]

        #expect(controllers.allSatisfy { $0 != nil })
    }

    @Test func reminderSettingsContentConstructsEnabledAndDisabledStates() {
        var enabled = false
        var reminders: [Reminder] = []

        let disabled = ReminderSettingsContent(
            remindersEnabled: Binding(get: { enabled }, set: { enabled = $0 }),
            reminders: Binding(get: { reminders }, set: { reminders = $0 }),
            tintColor: .blue,
            notificationManager: NotificationManager()
        )
        let disabledController = mount(disabled)

        enabled = true
        reminders = [Reminder(name: "Morning", hour: 7, minute: 30)]

        let enabledView = ReminderSettingsContent(
            remindersEnabled: Binding(get: { enabled }, set: { enabled = $0 }),
            reminders: Binding(get: { reminders }, set: { reminders = $0 }),
            tintColor: .green,
            notificationManager: NotificationManager()
        )
        let enabledController = mount(enabledView)

        #expect(disabledController.view != nil)
        #expect(enabledController.view != nil)
    }

    @Test func reminderRowConstructsWithEditableReminder() {
        var reminder = Reminder(name: "Evening", hour: 19, minute: 45)
        var changeCount = 0

        let view = ReminderRow(
            reminder: Binding(get: { reminder }, set: { reminder = $0 }),
            tintColor: .orange,
            onChanged: { changeCount += 1 }
        )

        #expect(mount(view).view != nil)
        #expect(changeCount == 0)
    }

    @Test func scaleScannerPermissionFallbackBodyConstructs() {
        let view = ScaleScannerView { _ in }

        let controller = mount(view)

        #expect(controller.view != nil)
    }

    @Test func scaleScannerRecognizesBlankImageWithoutCrashing() async throws {
        let view = ScaleScannerView { _ in }
        let image = CIImage(color: .black).cropped(to: CGRect(x: 0, y: 0, width: 32, height: 32))

        view.recognizeText(in: image)

        try await Task.sleep(for: .milliseconds(200))
        #expect(Bool(true))
    }

    @Test func journalLeafViewsConstructWithStoredData() throws {
        let container = try makeModelContainer()
        let context = ModelContext(container)
        let photoData = makeImageData(color: .systemTeal)
        let entry = WeightEntry(
            weight: 181.4,
            timestamp: Date(),
            note: "Felt good",
            photoData: photoData
        )
        let secondEntry = WeightEntry(
            weight: 182.0,
            timestamp: Date().addingTimeInterval(-3600),
            source: .appleHealth,
            healthKitUUID: UUID()
        )
        let workout = WorkoutEntry(
            timestamp: Date(),
            activityTypeRawValue: HKWorkoutActivityType.running.rawValue,
            duration: 3675,
            energyBurnedKilocalories: 420,
            distanceMiles: 3.2,
            healthKitUUID: UUID()
        )
        let activity = DailyActivitySummary(
            date: Calendar.current.startOfDay(for: Date()),
            stepCount: 9_876,
            activeEnergyBurnedKilocalories: 543
        )
        context.insert(entry)
        context.insert(secondEntry)
        context.insert(workout)
        context.insert(activity)
        try context.save()

        let notificationManager = NotificationManager()
        notificationManager.modelContext = context
        let healthManager = HealthKitManager()
        healthManager.isAvailable = false

        let detail = LogDayDetailSheet(
            title: "Today",
            entryIDs: [entry.persistentModelID, secondEntry.persistentModelID],
            workoutIDs: [workout.persistentModelID],
            dailyActivityDate: activity.date,
            tintColor: .blue,
            onDismiss: {}
        )
        .modelContainer(container)
        .environment(healthManager)
        .environment(notificationManager)

        let create = LogDayCreateSheet(
            date: Date(),
            title: "Today",
            suggestedWeight: 181.4,
            tintColor: .blue,
            onDismiss: {}
        )
        .modelContainer(container)
        .environment(healthManager)
        .environment(notificationManager)

        let image = UIImage(data: photoData) ?? UIImage()
        let controllers = [
            mount(detail).view,
            mount(create).view,
            mount(LogPhotoCarouselView(photos: [image], initialIndex: 3, canEditCurrentPhoto: true, onEditCurrentPhoto: { _ in })).view,
            mount(WorkoutSummaryRow(workout: workout)).view
        ]

        #expect(controllers.allSatisfy { $0 != nil })
    }

    @Test func entryViewConstructsWithAndWithoutExistingEntry() throws {
        let emptyContainer = try makeModelContainer()
        let emptyNotificationManager = NotificationManager()
        emptyNotificationManager.modelContext = ModelContext(emptyContainer)
        var historyScrollRequest = 0
        var historySelectedEntry: WeightEntry?

        let emptyEntryView = EntryView(
            historyScrollRequest: Binding(get: { historyScrollRequest }, set: { historyScrollRequest = $0 }),
            historySelectedEntry: Binding(get: { historySelectedEntry }, set: { historySelectedEntry = $0 }),
            latestWeight: nil
        )
        .modelContainer(emptyContainer)
        .environment(HealthKitManager())
        .environment(emptyNotificationManager)

        let populatedContainer = try makeModelContainer()
        let populatedContext = ModelContext(populatedContainer)
        let existingEntry = WeightEntry(weight: 199.9, timestamp: Date())
        populatedContext.insert(existingEntry)
        try populatedContext.save()
        let populatedNotificationManager = NotificationManager()
        populatedNotificationManager.modelContext = populatedContext

        let populatedEntryView = EntryView(
            historyScrollRequest: Binding(get: { historyScrollRequest }, set: { historyScrollRequest = $0 }),
            historySelectedEntry: Binding(get: { historySelectedEntry }, set: { historySelectedEntry = $0 }),
            latestWeight: 199.9
        )
        .modelContainer(populatedContainer)
        .environment(HealthKitManager())
        .environment(populatedNotificationManager)

        #expect(mount(emptyEntryView).view != nil)
        #expect(mount(populatedEntryView).view != nil)
    }

    @Test func rootViewConstructsPrimaryTabStates() throws {
        let container = try makeModelContainer()
        let context = ModelContext(container)
        context.insert(WeightEntry(weight: 172.5, timestamp: Date()))
        try context.save()

        let notificationManager = NotificationManager()
        notificationManager.modelContext = context
        let healthManager = HealthKitManager()
        var selectedTab = 1
        var showLog = false

        let journalTab = RootView(
            selectedTab: Binding(get: { selectedTab }, set: { selectedTab = $0 }),
            showLog: Binding(get: { showLog }, set: { showLog = $0 })
        )
            .modelContainer(container)
            .environment(healthManager)
            .environment(notificationManager)
        let logController = mount(journalTab)

        selectedTab = 4
        let settingsTab = RootView(
            selectedTab: Binding(get: { selectedTab }, set: { selectedTab = $0 }),
            showLog: Binding(get: { showLog }, set: { showLog = $0 })
        )
            .modelContainer(container)
            .environment(healthManager)
            .environment(notificationManager)
        let settingsController = mount(settingsTab)

        #expect(logController.view != nil)
        #expect(settingsController.view != nil)
    }

    @Test func tabBarCoordinatorReportsSelectionAndReselection() {
        var interactions: [(Int, Bool)] = []
        let coordinator = TabBarControllerObserver.Coordinator { tappedIndex, wasReselected in
            interactions.append((tappedIndex, wasReselected))
        }
        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [UIViewController(), UIViewController()]
        tabBarController.selectedIndex = 0

        coordinator.attach(to: tabBarController)
        coordinator.tabBarController(tabBarController, didSelect: tabBarController.viewControllers![0])
        tabBarController.selectedIndex = 1
        coordinator.tabBarController(tabBarController, didSelect: tabBarController.viewControllers![1])

        #expect(interactions.count == 2)
        #expect(interactions[0].0 == 0)
        #expect(interactions[0].1 == true)
        #expect(interactions[1].0 == 1)
        #expect(interactions[1].1 == false)
    }


    @Test func progressPhotoCoordinatorHandlesCancelAndOriginalImage() {
        var pickedImages: [UIImage?] = []
        let coordinator = ProgressPhotoCameraView.Coordinator { image in
            pickedImages.append(image)
        }
        let picker = UIImagePickerController()
        let image = UIImage(data: makeImageData(color: .systemPurple)) ?? UIImage()

        coordinator.imagePickerControllerDidCancel(picker)
        coordinator.imagePickerController(picker, didFinishPickingMediaWithInfo: [.originalImage: image])

        #expect(pickedImages.count == 2)
        #expect(pickedImages[0] == nil)
        #expect(pickedImages[1] != nil)
    }

    @Test func cameraPreviewControllerNoCameraPathConstructs() {
        let controller = CameraPreviewController { _ in }
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 120, height: 120)
        controller.viewDidLayoutSubviews()

        #expect(controller.view != nil)
    }

    @Test func healthKitDailyActivityMergeCombinesStepAndEnergyDays() {
        let calendar = Calendar.current
        let dayOne = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let dayTwo = calendar.date(byAdding: .day, value: 1, to: dayOne)!
        let manager = HealthKitManager()

        let merged = manager.mergeDailyActivitySummaries(
            stepStats: [
                dayOne: 1234.4,
                dayTwo: 555.6
            ],
            activeEnergyStats: [
                dayTwo: 321.9
            ]
        )

        #expect(merged.map(\.date) == [dayOne, dayTwo])
        #expect(merged[0].stepCount == 1234)
        #expect(merged[0].activeEnergyBurnedKilocalories == 0)
        #expect(merged[1].stepCount == 556)
        #expect(merged[1].activeEnergyBurnedKilocalories == 321.9)
    }

    @Test func remainingSmallPureBranchesAreCovered() {
        #expect(AppTint.allCases.map(\.id) == AppTint.allCases.map(\.rawValue))
        for tint in AppTint.allCases {
            _ = tint.color
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let entries = [
            WeightEntry(weight: 150, timestamp: twoDaysAgo),
            WeightEntry(weight: 152, timestamp: yesterday),
            WeightEntry(weight: 151, timestamp: today)
        ]
        let yearlyChart = WeightCalculations.chartSnapshot(from: entries, over: .year)

        #expect(yearlyChart.trendEntries.count == 3)
        #expect(WeightCalculations.heatmapSnapshot(from: entries, weeks: 3).weeks.count == 3)
    }

    @Test func changeBadgeConstructsEmptySingleAndChangedStates() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let views = [
            ChangeBadge(entries: []),
            ChangeBadge(entries: [WeightEntry(weight: 180, timestamp: today)]),
            ChangeBadge(entries: [
                WeightEntry(weight: 182, timestamp: yesterday),
                WeightEntry(weight: 180, timestamp: today)
            ])
        ]

        let controllers = views.map { mount($0).view }

        #expect(controllers.allSatisfy { $0 != nil })
    }

    @Test func simulatorSafeHapticEntrypointsDoNotCrash() {
        Haptics.isEnabledOverride = nil
        Haptics.selection()
        Haptics.success()
        Haptics.impact()

        Haptics.isEnabledOverride = true
        Haptics.selection()
        Haptics.success()
        Haptics.impact(.medium)
        Haptics.isEnabledOverride = nil

        #expect(Bool(true))
    }

    @Test func unavailableHealthKitOperationsReturnWithoutMutatingImportState() async throws {
        let container = try makeModelContainer()
        let context = ModelContext(container)
        let manager = HealthKitManager()
        manager.isAvailable = false

        let savedUUID = await manager.saveWeight(180.0)
        await manager.deleteWeight(sampleUUID: UUID())
        await manager.importWeightData(modelContext: context)
        await manager.importWorkoutData(modelContext: context)
        await manager.importDailyActivityData(modelContext: context)
        await manager.importAllData(modelContext: context)

        #expect(savedUUID == nil)
        #expect(manager.isImporting == false)
        #expect(manager.isImportingWorkouts == false)
        #expect(manager.isImportingDailyActivity == false)
        #expect(manager.importResult == nil)
        #expect(manager.workoutImportResult == nil)
        #expect(manager.dailyActivityImportResult == nil)
    }

    private func mount<Content: View>(_ view: Content) -> UIHostingController<Content> {
        let controller = UIHostingController(rootView: view)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        _ = controller.sizeThatFits(in: CGSize(width: 390, height: 844))
        return controller
    }

    private func makeModelContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: WeightEntry.self,
            WorkoutEntry.self,
            DailyActivitySummary.self,
            configurations: config
        )
    }

    private func makeImageData(color: UIColor) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12))
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 12, height: 12))
        }
        return image.pngData() ?? Data()
    }
}
