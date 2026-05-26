//
//  OnboardingView.swift
//  Scale
//
//  Created by Jonathan Groberg on 4/14/26.
//

import ConfettiSwiftUI
import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding_v2") private var hasCompletedOnboarding = false
    @AppStorage("remindersEnabled") private var remindersEnabled = false
    @AppStorage("autoSyncHealthKit") private var autoSyncHealthKit = false
    @AppStorage("appTint") private var appTint = AppTint.defaultValue.rawValue
    @AppStorage("customTintHex") private var customTintHex = ""
    @AppStorage("weightGoal") private var weightGoal = WeightGoal.defaultValue.rawValue
    @AppStorage("cutTargetWeight") private var cutTargetWeight = 180.0
    @AppStorage("bulkTargetWeight") private var bulkTargetWeight = 180.0
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(HealthKitManager.self) private var healthManager
    @State private var currentPage = 0
    @State private var reminders: [Reminder] = []
    @State private var miniGoals: [MiniGoal] = []
    @State private var isRequestingHealthPermission = false
    @State private var isCompletingOnboarding = false
    @State private var onboardingConfettiTrigger = 0

    private var selectedTint: Binding<AppTint> {
        Binding(
            get: { AppTint(rawValue: appTint) ?? .defaultValue },
            set: { appTint = $0.rawValue }
        )
    }

    private var selectedGoal: Binding<WeightGoal> {
        Binding(
            get: { WeightGoal(rawValue: weightGoal) ?? .defaultValue },
            set: { weightGoal = $0.rawValue }
        )
    }

    private var selectedTargetWeight: Binding<Double> {
        Binding(
            get: {
                switch selectedGoal.wrappedValue {
                case .lose: cutTargetWeight
                case .maintain: cutTargetWeight
                case .gain: bulkTargetWeight
                }
            },
            set: { newValue in
                switch selectedGoal.wrappedValue {
                case .lose: cutTargetWeight = newValue
                case .maintain: break
                case .gain: bulkTargetWeight = newValue
                }
            }
        )
    }

    private var tintColor: Color {
        (AppTint(rawValue: appTint) ?? .defaultValue).color
    }

    private var customColor: Binding<Color> {
        Binding(
            get: {
                guard !customTintHex.isEmpty, let color = Color(hex: customTintHex) else {
                    return .blue
                }
                return color
            },
            set: { customTintHex = $0.toHex() }
        )
    }

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "scalemass",
            usesAppIcon: false,
            title: "Track Your Weight",
            subtitle: "Log daily weigh-ins with a single tap. Scan your scale or type it in."
        ),
        OnboardingPage(
            icon: "chart.xyaxis.line",
            title: "See Your Progress",
            subtitle: "View trends over time in your journal with charts and streaks."
        ),
        OnboardingPage(
            icon: "target",
            title: "Choose Your Goal",
            subtitle: "Set whether you want to cut, maintain, or bulk. You can change it anytime."
        ),
        OnboardingPage(
            icon: "paintpalette.fill",
            title: "Pick Your Theme",
            subtitle: "Choose the accent color that feels right for your log."
        ),
        OnboardingPage(
            icon: "heart.fill",
            title: "Connect Apple Health",
            subtitle: "Sync your Oura Ring, smartwatch, or other data via Apple Health."
        ),
        OnboardingPage(
            icon: "bell.badge.fill",
            title: "Stay Consistent",
            subtitle: "Set daily reminders so you never miss a weigh-in."
        ),
        OnboardingPage(
            icon: nil,
            title: "Widgets",
            subtitle: "Add a widget to your Home Screen or Lock Screen for quick access to your progress."
        ),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    pageView(page, index: index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            bottomControls
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .tint(tintColor)
        .confettiCannon(
            trigger: $onboardingConfettiTrigger,
            num: 85,
            colors: [tintColor, .pink, .orange, .mint, .cyan, .yellow],
            confettiSize: 11,
            radius: 380,
            repetitions: 2,
            repetitionInterval: 0.22,
            hapticFeedback: false
        )
        .onAppear {
            reminders = notificationManager.loadReminders()
        }
    }

    // MARK: - Page Content

    private func pageView(_ page: OnboardingPage, index: Int) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                Spacer(minLength: 24)

                if let icon = page.icon {
                    Image(systemName: icon)
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)
                        .padding(.bottom, 8)
                }

                Text(page.title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                if index < 2 {
                    onboardingIllustration(for: index)
                        .padding(.top, index == 0 ? 40 : 8)
                        .padding(.horizontal, 28)
                } else if index == 2 {
                    goalSetupCard
                        .padding(.top, 12)
                        .padding(.horizontal, 24)
                } else if index == 3 {
                    themeSetupCard
                        .padding(.top, 12)
                        .padding(.horizontal, 24)
                } else if index == 4 {
                    healthSetupCard
                        .padding(.top, 12)
                        .padding(.horizontal, 24)
                } else if index == pages.count - 2 {
                    remindersSetupCard
                        .padding(.top, 12)
                        .padding(.horizontal, 24)
                } else if index == pages.count - 1 {
                    widgetSetupCard
                        .padding(.top, 36)
                }

                Spacer(minLength: 40)
            }
            .padding(.bottom, 180)
            .frame(maxWidth: .infinity, minHeight: 0)
        }
    }

    @ViewBuilder
    private func onboardingIllustration(for index: Int) -> some View {
        ZStack {
            if index == 0 {
                // Card 1: Typed manual entry
                PlaceholderPhotoCard(
                    title: "Manual log",
                    subtitle: "Quick keyboard entry",
                    background: LinearGradient(
                        colors: [tintColor, tintColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    accent: Color.white.opacity(0.92),
                    systemImage: "keyboard"
                )
                .rotationEffect(.degrees(-8))
                .offset(x: -54, y: 20)

                // Card 2: Scanned entry via camera/photo
                PlaceholderPhotoCard(
                    title: "Quick scan",
                    subtitle: "Parsed from scale photo",
                    background: LinearGradient(
                        colors: [tintColor.opacity(0.65), tintColor.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    accent: Color.white.opacity(0.92),
                    systemImage: "barcode.viewfinder"
                )
                .rotationEffect(.degrees(7))
                .offset(x: 46, y: -18)
            } else {
                PlaceholderGraphCard(tintColor: tintColor)
                    .rotationEffect(.degrees(-7))
                    .offset(x: -52, y: 26)

                PlaceholderCalendarCard(tintColor: tintColor)
                    .rotationEffect(.degrees(6))
                    .offset(x: 50, y: -12)

                PlaceholderMiniGraphCard(tintColor: tintColor)
                    .rotationEffect(.degrees(-2))
                    .offset(x: 6, y: 74)
            }
        }
        .frame(height: 270)
    }

    private var goalSetupCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("You can change this later in Settings.", systemImage: "gearshape")
                .font(.caption)
                .foregroundStyle(.secondary)

            GoalPicker(selection: selectedGoal, tintColor: tintColor)

            if selectedGoal.wrappedValue.showsTarget {
                Divider()

                TargetWeightRow(
                    goal: selectedGoal.wrappedValue,
                    targetWeight: selectedTargetWeight,
                    tintColor: tintColor
                )

                ForEach($miniGoals) { $miniGoal in
                    Divider()

                    MiniGoalRow(
                        miniGoal: $miniGoal,
                        goal: selectedGoal.wrappedValue,
                        mainTarget: selectedTargetWeight.wrappedValue,
                        tintColor: tintColor
                    ) {
                        MiniGoalStore.save(miniGoals, for: selectedGoal.wrappedValue)
                    }
                    .padding(.leading, 32)
                }

                Divider()

                Button {
                    withAnimation {
                        miniGoals.append(
                            MiniGoal(
                                parentGoal: selectedGoal.wrappedValue,
                                targetWeight: MiniGoalStore.defaultTarget(
                                    for: selectedGoal.wrappedValue,
                                    mainTarget: selectedTargetWeight.wrappedValue,
                                    existingGoals: miniGoals
                                )
                            )
                        )
                    }
                    MiniGoalStore.save(miniGoals, for: selectedGoal.wrappedValue)
                    Haptics.selection()
                } label: {
                    Label("Add mini goal", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 32)
                }
                .buttonStyle(.plain)
                .foregroundStyle(tintColor)
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .animation(.snappy, value: selectedGoal.wrappedValue)
        .onChange(of: selectedGoal.wrappedValue) { _, newGoal in
            miniGoals = MiniGoalStore.load(for: newGoal)
        }
        .onAppear {
            miniGoals = MiniGoalStore.load(for: selectedGoal.wrappedValue)
        }
    }

    private var remindersSetupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("You can change this later in Settings.", systemImage: "gearshape")
                .font(.caption)
                .foregroundStyle(.secondary)

            ReminderSettingsContent(
                remindersEnabled: $remindersEnabled,
                reminders: $reminders,
                tintColor: tintColor,
                notificationManager: notificationManager
            )
        }
            .padding(20)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var widgetSetupCard: some View {
        VStack(spacing: 28) {
            ZStack {
                lockScreenPhoneCard
                    .rotationEffect(.degrees(-6))
                    .offset(x: -40, y: 14)

                homeScreenPhoneCard
                    .rotationEffect(.degrees(5))
                    .offset(x: 40, y: -10)
            }
            .frame(height: 280)

            Label("Add widgets by long-pressing your Home Screen or Lock Screen", systemImage: "plus.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 24)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 32)
    }

    private var lockScreenPhoneCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(spacing: 2) {
                Text("TUESDAY, SEPTEMBER 15")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(0.5)
                
                Text("9:41")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 22)

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "scalemass.fill")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(tintColor)
                    Text("Scale")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(tintColor)
                    Spacer()
                    Text("yesterday")
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 2)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("142.5")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("lb")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 3)
                }

                HStack(spacing: 4) {
                    HStack(spacing: 2) {
                        Text("Streak")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("6d")
                            .font(.system(size: 7, weight: .bold, design: .rounded))
                            .foregroundStyle(tintColor)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(tintColor.opacity(0.14), in: Capsule())

                    HStack(spacing: 2) {
                        Text("30D")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("-1.4%")
                            .font(.system(size: 7, weight: .bold, design: .rounded))
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(tintColor.opacity(0.14), in: Capsule())
                }
            }
            .padding(10)
            .frame(width: 130)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.12))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.15), lineWidth: 1.5)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
        }
        .frame(width: 168)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.32, green: 0.18, blue: 0.44), // Cosmic purple
                    Color(red: 0.18, green: 0.14, blue: 0.32), // Deep violet
                    Color(red: 0.08, green: 0.08, blue: 0.14)  // Midnight black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.25), lineWidth: 3)
        }
        .shadow(color: .black.opacity(0.2), radius: 24, y: 12)
    }

    private var homeScreenPhoneCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 4) {
                Text("9:41")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "cellularbars")
                        .font(.system(size: 10))
                    Image(systemName: "wifi")
                        .font(.system(size: 10))
                    Image(systemName: "battery.100")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.white)
            }
            .padding(.top, 16)
            .padding(.horizontal, 14)

            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(tintColor)
                    Text("Streak")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 0)

                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("12")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("days")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer(minLength: 0)

                Text("Best: 24 days")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(10)
            .frame(width: 100, height: 100, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.12))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.15), lineWidth: 1.5)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 40)
        }
        .frame(width: 168)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.42, blue: 0.74), // Royal twilight blue
                    Color(red: 0.18, green: 0.22, blue: 0.48), // Royal twilight indigo
                    Color(red: 0.08, green: 0.10, blue: 0.18)  // Dark twilight black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.25), lineWidth: 3)
        }
        .shadow(color: .black.opacity(0.2), radius: 24, y: 12)
    }

    private var themeSetupCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(AppTint.presets) { tint in
                Button {
                    selectedTint.wrappedValue = tint
                    Haptics.selection()
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(tint.color)
                            .frame(width: 20, height: 20)

                        Text(tint.title)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                        Spacer()

                        if selectedTint.wrappedValue == tint {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(tint.color)
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(
                        tint.color.opacity(selectedTint.wrappedValue == tint ? 0.14 : 0.06),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                selectedTint.wrappedValue == tint ? tint.color.opacity(0.7) : Color.secondary.opacity(0.16),
                                lineWidth: 1
                            )
                    }
                }
                .buttonStyle(.plain)
            }

            customThemeRow
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var customThemeRow: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(selectedTint.wrappedValue == .custom ? tintColor : Color.gray.opacity(0.3))
                .frame(width: 20, height: 20)

            Text("Custom")
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)

            Spacer()

            ColorPicker("", selection: customColor, supportsOpacity: false)
                .labelsHidden()
                .onChange(of: customTintHex) { _, _ in
                    selectedTint.wrappedValue = .custom
                    Haptics.selection()
                }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(
            tintColor.opacity(selectedTint.wrappedValue == .custom ? 0.14 : 0.06),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    selectedTint.wrappedValue == .custom ? tintColor.opacity(0.7) : Color.secondary.opacity(0.16),
                    lineWidth: 1
                )
        }
    }

    private var healthSetupCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if healthManager.isAvailable {
                Label("You can change this later in Settings.", systemImage: "gearshape")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle(isOn: healthSyncBinding) {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Apple Health Sync")
                            .font(.body.weight(.semibold))
                        Text(healthManager.isAvailable ? "Import your Health data when Scale opens." : "Apple Health is not available on this device.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    if isRequestingHealthPermission {
                        ProgressView()
                    } else {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(tintColor)
                    }
                }
            }
            .disabled(!healthManager.isAvailable || isRequestingHealthPermission)
            .onChange(of: autoSyncHealthKit) { _, enabled in
                guard enabled, healthManager.isAvailable else { return }
                isRequestingHealthPermission = true
                Task {
                    let granted = await healthManager.requestImportPermission()
                    await MainActor.run {
                        autoSyncHealthKit = granted
                        isRequestingHealthPermission = false
                    }
                }
            }

            if healthManager.isAvailable && autoSyncHealthKit {
                Divider()

                HealthImportRows(tintColor: tintColor)
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var healthSyncBinding: Binding<Bool> {
        Binding(
            get: { healthManager.isAvailable && autoSyncHealthKit },
            set: { autoSyncHealthKit = healthManager.isAvailable && $0 }
        )
    }

    private func finishOnboarding() {
        guard !isCompletingOnboarding else { return }
        isCompletingOnboarding = true
        onboardingConfettiTrigger += 1
        Haptics.success()

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            completeOnboarding()
        }
    }

    private func completeOnboarding() {
        if !healthManager.isAvailable {
            autoSyncHealthKit = false
        }
        if remindersEnabled && reminders.isEmpty {
            reminders = [Reminder()]
            notificationManager.saveReminders(reminders)
        } else if remindersEnabled {
            notificationManager.rescheduleReminders()
        }
        hasCompletedOnboarding = true
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? tintColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut, value: currentPage)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.08), radius: 16, y: 6)

            Button {
                if currentPage < pages.count - 1 {
                    withAnimation { currentPage += 1 }
                } else {
                    finishOnboarding()
                }
            } label: {
                Text(currentPage < pages.count - 1 ? "Next" : isCompletingOnboarding ? "You're In" : "Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .disabled(isCompletingOnboarding)
        }
    }
}

// MARK: - Model

private struct OnboardingPage {
    let icon: String?
    var usesAppIcon: Bool = false
    let title: String
    let subtitle: String
}

struct PlaceholderPhotoCard: View {
    let title: String
    let subtitle: String
    let background: LinearGradient
    let accent: Color
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottom) {
                background

                VStack(spacing: 12) {
                    Spacer()

                    Circle()
                        .fill(accent.opacity(0.28))
                        .frame(width: 74, height: 74)
                        .overlay {
                            Image(systemName: systemImage)
                                .font(.system(size: 34, weight: .medium))
                                .foregroundStyle(accent)
                        }

                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(accent.opacity(0.24))
                        .frame(width: 108, height: 112)
                }
                .padding(.bottom, 12)
            }
            .frame(height: 192)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
        }
        .frame(width: 170)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.12), radius: 24, y: 12)
    }
}

struct PlaceholderCalendarCard: View {
    var tintColor: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Calendar")
                    .font(.headline)
                Spacer()
                Image(systemName: "calendar")
                    .foregroundStyle(.tint)
            }

            HStack(spacing: 8) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                    Text(day)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            VStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<7, id: \.self) { column in
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(calendarCellColor(row: row, column: column))
                                .frame(height: 26)
                                .overlay {
                                    if row == 1 && column == 3 {
                                        Image(systemName: "scalemass")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(width: 190)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.12), radius: 24, y: 12)
    }

    private func calendarCellColor(row: Int, column: Int) -> Color {
        if row == 1 && column == 3 {
            return tintColor
        }
        if (row + column).isMultiple(of: 3) {
            return tintColor.opacity(0.16)
        }
        return Color(.secondarySystemGroupedBackground)
    }
}

struct PlaceholderGraphCard: View {
    var tintColor: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Progress")
                    .font(.headline)
                Spacer()
                Text("-6.2 lb")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            }

            HStack(alignment: .bottom, spacing: 10) {
                ForEach([0.32, 0.55, 0.48, 0.72, 0.62, 0.82], id: \.self) { value in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tintColor.opacity(0.35), tintColor],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 18, height: 120 * value)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .bottomLeading)

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .frame(height: 34)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.green.opacity(0.18))
                        .frame(width: 116, height: 34)
                }
        }
        .padding(18)
        .frame(width: 184)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.12), radius: 24, y: 12)
    }
}

struct PlaceholderMiniGraphCard: View {
    var tintColor: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trend")
                .font(.subheadline.weight(.semibold))

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))

                Path { path in
                    path.move(to: CGPoint(x: 12, y: 66))
                    path.addCurve(
                        to: CGPoint(x: 132, y: 18),
                        control1: CGPoint(x: 42, y: 24),
                        control2: CGPoint(x: 94, y: 52)
                    )
                }
                .stroke(tintColor, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .padding(10)
            }
            .frame(height: 88)
        }
        .padding(16)
        .frame(width: 158)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
    }
}

#Preview("Onboarding — Page 1") {
    OnboardingView()
        .environment(HealthKitManager())
        .environment(NotificationManager())
}

#Preview("Onboarding — All Pages") {
    OnboardingPreviewPages()
        .environment(HealthKitManager())
        .environment(NotificationManager())
}

struct OnboardingPreviewPages: View {
    @State private var page = 0
    var body: some View {
        VStack(spacing: 16) {
            OnboardingViewWrapper(currentPage: $page)
                .frame(maxHeight: .infinity)
            HStack(spacing: 12) {
                Button("Prev") { if page > 0 { page -= 1 } }
                Button("Next") { if page < 5 { page += 1 } }
                Button("Reset") { page = 0 }
            }
            .buttonStyle(.bordered)
            .padding(.bottom)
        }
        .padding()
    }
}

struct OnboardingViewWrapper: View {
    @Binding var currentPage: Int
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(HealthKitManager.self) private var healthManager
    var body: some View {
        OnboardingView()
            .environment(notificationManager)
            .environment(healthManager)
            .onAppear { /* no-op, exists to ensure environment is passed */ }
            .onChange(of: currentPage) { _, _ in }
            .overlay(alignment: .topTrailing) {
                Text("Page: \(currentPage + 1)")
                    .font(.caption)
                    .padding(8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(8)
            }
    }
}
