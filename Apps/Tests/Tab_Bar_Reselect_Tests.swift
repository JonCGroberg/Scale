//
//  Tab_Bar_Reselect_Tests.swift
//  ScaleTests
//
//  Split from monolithic ScaleTests.swift for maintainability.
//

import Testing
import Foundation
import SwiftUI
import SwiftData
import UserNotifications
import XCTest
@testable import Scale

// MARK: - Tab Bar Reselect Tests

@MainActor
struct TabBarControllerObserverTests {

    @Test func attachSeedsCurrentSelectedIndexForReselectDetection() {
        let controller = UITabBarController()
        controller.viewControllers = [UIViewController(), UIViewController(), UIViewController()]
        controller.selectedIndex = 1

        var receivedTap: (index: Int, wasReselected: Bool)?
        let coordinator = TabBarControllerObserver.Coordinator { tappedIndex, wasReselected in
            receivedTap = (tappedIndex, wasReselected)
        }

        coordinator.attach(to: controller)
        coordinator.tabBarController(controller, didSelect: controller.viewControllers![1])

        #expect(receivedTap?.index == 1)
        #expect(receivedTap?.wasReselected == true)
    }

    @Test func selectingDifferentTabReportsNonReselect() {
        let controller = UITabBarController()
        controller.viewControllers = [UIViewController(), UIViewController(), UIViewController()]
        controller.selectedIndex = 0

        var receivedTap: (index: Int, wasReselected: Bool)?
        let coordinator = TabBarControllerObserver.Coordinator { tappedIndex, wasReselected in
            receivedTap = (tappedIndex, wasReselected)
        }

        coordinator.attach(to: controller)
        controller.selectedIndex = 1
        coordinator.tabBarController(controller, didSelect: controller.viewControllers![1])

        #expect(receivedTap?.index == 1)
        #expect(receivedTap?.wasReselected == false)
    }

    @Test func switchingToJournalThenRetappingReportsReselectOnlyOnSecondTap() {
        let controller = UITabBarController()
        controller.viewControllers = [UIViewController(), UIViewController(), UIViewController()]
        controller.selectedIndex = 0

        var receivedTaps: [(index: Int, wasReselected: Bool)] = []
        let coordinator = TabBarControllerObserver.Coordinator { tappedIndex, wasReselected in
            receivedTaps.append((tappedIndex, wasReselected))
        }

        coordinator.attach(to: controller)

        controller.selectedIndex = 1
        coordinator.tabBarController(controller, didSelect: controller.viewControllers![1])
        coordinator.tabBarController(controller, didSelect: controller.viewControllers![1])

        #expect(receivedTaps.count == 2)
        #expect(receivedTaps[0].index == 1)
        #expect(receivedTaps[0].wasReselected == false)
        #expect(receivedTaps[1].index == 1)
        #expect(receivedTaps[1].wasReselected == true)
    }
}

