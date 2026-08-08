//
//  Overview_Loading_State_Tests.swift
//  ScaleTests
//

import Testing
@testable import Scale

struct OverviewLoadingStateTests {
    @Test func firstLoadWithoutChartsShowsLoadingInsteadOfEmpty() {
        #expect(OverviewChartContentState.resolve(hasCompletedInitialLoad: false, visibleChartCount: 0) == .loading)
    }

    @Test func firstLoadCanShowImmediatelyAvailableWeightChart() {
        #expect(OverviewChartContentState.resolve(hasCompletedInitialLoad: false, visibleChartCount: 1) == .charts)
    }

    @Test func completedLoadWithoutDataShowsTrueEmptyState() {
        #expect(OverviewChartContentState.resolve(hasCompletedInitialLoad: true, visibleChartCount: 0) == .empty)
    }

    @Test func refreshKeepsPreviouslyLoadedChartsVisible() {
        #expect(OverviewChartContentState.resolve(hasCompletedInitialLoad: true, visibleChartCount: 4) == .charts)
    }
}
