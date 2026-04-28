//
//  OnboardingView.swift
//  Scale
//
//  Created by Jonathan Groberg on 4/14/26.
//

import ConfettiSwiftUI
import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("remindersEnabled") private var remindersEnabled = false
    @AppStorage("autoSyncHealthKit") private var autoSyncHealthKit = false
    @AppStorage("appTint") private var appTint = AppTint.defaultValue.rawValue
    @AppStorage("weightGoal") private var weightGoal = WeightGoal.defaultValue.rawValue
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(HealthKitManager.self) private var healthManager
    @State private var currentPage = 0
    @State private var reminders: [Reminder] = []
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

    private var tintColor: Color {
        (AppTint(rawValue: appTint) ?? .defaultValue).color
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
            subtitle: "Import weight entries, workouts, steps, and active calories automatically."
        ),
        OnboardingPage(
            icon: "bell.badge.fill",
            title: "Stay Consistent",
            subtitle: "Set daily reminders so you never miss a weigh-in."
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
                        .padding(.top, 8)
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
                } else if index == pages.count - 1 {
                    remindersSetupCard
                        .padding(.top, 12)
                        .padding(.horizontal, 24)
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
                PlaceholderPhotoCard(
                    title: "Morning weigh-in",
                    subtitle: "Camera capture",
                    background: LinearGradient(
                        colors: [Color(red: 0.98, green: 0.90, blue: 0.76), Color(red: 0.89, green: 0.69, blue: 0.53)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    accent: Color.white.opacity(0.9),
                    systemImage: "figure.stand"
                )
                .rotationEffect(.degrees(-8))
                .offset(x: -54, y: 20)

                PlaceholderPhotoCard(
                    title: "Quick scan",
                    subtitle: "Typed or scanned",
                    background: LinearGradient(
                        colors: [Color(red: 0.81, green: 0.90, blue: 0.99), Color(red: 0.53, green: 0.73, blue: 0.95)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    accent: Color.white.opacity(0.92),
                    systemImage: "person.fill"
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
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
            .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var themeSetupCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(AppTint.allCases) { tint in
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
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
        .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
                .stroke(Color.white.opacity(0.85), lineWidth: 4)
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
                .stroke(Color.white.opacity(0.9), lineWidth: 4)
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
                .stroke(Color.white.opacity(0.9), lineWidth: 4)
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
                .stroke(Color.white.opacity(0.88), lineWidth: 4)
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
