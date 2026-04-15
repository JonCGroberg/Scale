//
//  Widget_Snapshot_Store_Tests.swift
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

// MARK: - Widget Snapshot Store Tests

@MainActor
final class WeightWidgetSnapshotStoreXCTests: XCTestCase {

    func testLoadFallsBackToEmptySnapshotWhenNoContainerIsAvailable() {
        let snapshot = WeightWidgetSnapshotStore.load()

        XCTAssertNotNil(snapshot)
    }

    func testWriteReturnsFalseWhenNoContainerIsAvailable() {
        let result = WeightWidgetSnapshotStore.write(.empty)

        if result {
            XCTAssertEqual(WeightWidgetSnapshotStore.load(), .empty)
        } else {
            XCTAssertEqual(WeightWidgetSnapshotStore.load(), .empty)
        }
    }

    func testWriteAndLoadRoundTripSnapshotAtExplicitURL() throws {
        let url = URL(filePath: NSTemporaryDirectory()).appending(path: "\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let snapshot = WeightWidgetSnapshot.make(
            from: [WeightEntry(weight: 182.4, timestamp: now)],
            tintRawValue: AppTint.green.rawValue,
            now: now
        )

        XCTAssertTrue(WeightWidgetSnapshotStore.write(snapshot, to: url, reloadTimelines: false))
        XCTAssertEqual(WeightWidgetSnapshotStore.load(from: url), snapshot)
    }

    func testLoadReturnsEmptyForCorruptSnapshotData() throws {
        let url = URL(filePath: NSTemporaryDirectory()).appending(path: "\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not-json".utf8).write(to: url)

        XCTAssertEqual(WeightWidgetSnapshotStore.load(from: url), .empty)
    }

    func testLoadReturnsEmptyWhenURLIsNil() {
        XCTAssertEqual(WeightWidgetSnapshotStore.load(from: nil), .empty)
    }

    func testWriteReturnsFalseWhenURLIsNil() {
        XCTAssertFalse(WeightWidgetSnapshotStore.write(.empty, to: nil, reloadTimelines: false))
    }

    func testLoadReturnsEmptyWhenSnapshotFileDoesNotExist() {
        let url = URL(filePath: NSTemporaryDirectory()).appending(path: "\(UUID().uuidString).json")

        XCTAssertEqual(WeightWidgetSnapshotStore.load(from: url), .empty)
    }

    func testWriteReturnsFalseWhenDestinationIsDirectory() throws {
        let directoryURL = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        XCTAssertFalse(WeightWidgetSnapshotStore.write(.empty, to: directoryURL, reloadTimelines: false))
    }
}

