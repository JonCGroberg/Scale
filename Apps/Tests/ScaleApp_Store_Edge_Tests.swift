//
//  ScaleApp_Store_Edge_Tests.swift
//  ScaleTests
//
//  Tests for ScaleApp.storeCompanionURLs, resetStoreFiles edge cases,
//  and makeModelContainer fallback behavior.
//

import Testing
import Foundation
import SwiftData
@testable import Scale

struct ScaleAppStoreEdgeTests {

    // MARK: - storeCompanionURLs

    @Test func companionURLsWithEmptySiblingsReturnsEmpty() {
        let storeURL = URL(filePath: "/tmp/test/default.store")
        let result = ScaleApp.storeCompanionURLs(for: storeURL, among: [])
        #expect(result.isEmpty)
    }

    @Test func companionURLsExcludesStoreURLItself() {
        let storeURL = URL(filePath: "/tmp/test/default.store")
        let siblings = [storeURL]
        let result = ScaleApp.storeCompanionURLs(for: storeURL, among: siblings)
        #expect(result.isEmpty)
    }

    @Test func companionURLsIncludesAllPrefixMatches() {
        let dir = URL(filePath: "/tmp/test")
        let storeURL = dir.appending(path: "Scale.sqlite")
        let siblings = [
            storeURL,
            dir.appending(path: "Scale.sqlite-wal"),
            dir.appending(path: "Scale.sqlite-shm"),
            dir.appending(path: "Scale.sqlite-journal")
        ]

        let result = ScaleApp.storeCompanionURLs(for: storeURL, among: siblings)

        #expect(result.count == 3)
        #expect(!result.contains(storeURL))
    }

    @Test func companionURLsIgnoresUnrelatedFiles() {
        let dir = URL(filePath: "/tmp/test")
        let storeURL = dir.appending(path: "Scale.sqlite")
        let siblings = [
            dir.appending(path: "Other.sqlite-wal"),
            dir.appending(path: "README.md"),
            dir.appending(path: "backup.store")
        ]

        let result = ScaleApp.storeCompanionURLs(for: storeURL, among: siblings)
        #expect(result.isEmpty)
    }

    // MARK: - resetStoreFiles

    @Test func resetStoreFilesHandlesNonExistentStore() throws {
        let root = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let storeURL = root.appending(path: "nonexistent.sqlite")
        let config = ModelConfiguration(url: storeURL)

        // Should not throw even though the store doesn't exist
        try ScaleApp.resetStoreFiles(for: config, fileManager: .default)
    }

    @Test func resetStoreFilesDeletesOnlyCompanions() throws {
        let root = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let storeURL = root.appending(path: "Test.sqlite")
        let walURL = root.appending(path: "Test.sqlite-wal")
        let unrelatedURL = root.appending(path: "Unrelated.txt")

        try Data().write(to: storeURL)
        try Data().write(to: walURL)
        try Data().write(to: unrelatedURL)

        let config = ModelConfiguration(url: storeURL)
        try ScaleApp.resetStoreFiles(for: config, fileManager: .default)

        #expect(!FileManager.default.fileExists(atPath: storeURL.path()))
        #expect(!FileManager.default.fileExists(atPath: walURL.path()))
        #expect(FileManager.default.fileExists(atPath: unrelatedURL.path()))
    }

    // MARK: - makeModelContainer

    @Test func makeModelContainerSucceedsWithInMemoryConfig() throws {
        let schema = Schema([WeightEntry.self, WorkoutEntry.self, DailyActivitySummary.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        let container = try ScaleApp.makeModelContainer(schema: schema, configuration: config)
        #expect(container.schema.entities.count > 0)
    }
}
