//
//  Store_Reset_Tests.swift
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

// MARK: - Store Reset Tests

struct StoreResetTests {

    @Test func companionURLsMatchStoreSidecarFilesOnly() {
        let directory = URL(filePath: "/tmp/ScaleTests")
        let storeURL = directory.appending(path: "default.store")
        let siblings = [
            storeURL,
            directory.appending(path: "default.store-wal"),
            directory.appending(path: "default.store-shm"),
            directory.appending(path: "default.sqlite"),
            directory.appending(path: "other.store-wal")
        ]

        let companions = ScaleApp.storeCompanionURLs(for: storeURL, among: siblings)

        #expect(companions.count == 2)
        #expect(companions.contains(directory.appending(path: "default.store-wal")))
        #expect(companions.contains(directory.appending(path: "default.store-shm")))
    }

    @Test func companionURLsReturnEmptyWhenNoMatchesExist() {
        let directory = URL(filePath: "/tmp/ScaleTests")
        let storeURL = directory.appending(path: "default.store")
        let siblings = [
            directory.appending(path: "other.store"),
            directory.appending(path: "other.store-wal")
        ]

        #expect(ScaleApp.storeCompanionURLs(for: storeURL, among: siblings).isEmpty)
    }

    @Test func resetStoreFilesDeletesStoreAndCompanions() throws {
        let rootURL = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let storeURL = rootURL.appending(path: "Scale.sqlite")
        let walURL = rootURL.appending(path: "Scale.sqlite-wal")
        let shmURL = rootURL.appending(path: "Scale.sqlite-shm")
        let unrelatedURL = rootURL.appending(path: "Other.sqlite")
        try Data().write(to: storeURL)
        try Data().write(to: walURL)
        try Data().write(to: shmURL)
        try Data().write(to: unrelatedURL)

        let configuration = ModelConfiguration(url: storeURL)
        try ScaleApp.resetStoreFiles(for: configuration, fileManager: .default)

        #expect(!FileManager.default.fileExists(atPath: storeURL.path()))
        #expect(!FileManager.default.fileExists(atPath: walURL.path()))
        #expect(!FileManager.default.fileExists(atPath: shmURL.path()))
        #expect(FileManager.default.fileExists(atPath: unrelatedURL.path()))
    }
}

