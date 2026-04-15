//
//  OnboardingView.swift
//  Scale
//
//  Created by Jonathan Groberg on 4/14/26.
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "scalemass.fill",
            title: "Track Your Weight",
            subtitle: "Log daily weigh-ins with a single tap. Scan your scale or type it in."
        ),
        OnboardingPage(
            icon: "chart.xyaxis.line",
            title: "See Your Progress",
            subtitle: "View trends over time in your journal with charts and streaks."
        ),
        OnboardingPage(
            icon: "bell.badge.fill",
            title: "Stay Consistent",
            subtitle: "Set daily reminders so you never miss a weigh-in."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    pageView(page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            bottomControls
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    // MARK: - Page Content

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .padding(.bottom, 8)

            Text(page.title)
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text(page.subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 20) {
            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut, value: currentPage)
                }
            }

            // Action button
            Button {
                if currentPage < pages.count - 1 {
                    withAnimation { currentPage += 1 }
                } else {
                    hasCompletedOnboarding = true
                }
            } label: {
                Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 14))
        }
    }
}

// MARK: - Model

private struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
}

#Preview {
    OnboardingView()
}
