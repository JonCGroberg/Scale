//
//  WeightWidgetSnapshotStore.swift
//  Scale
//
//  Created by Codex on 3/16/26.
//

import Foundation
import UniformTypeIdentifiers
import WidgetKit

enum WeightWidgetSnapshotStore {
    static let appGroupID = "group.groberg.Scale"
    static let widgetKind = "groberg.Scale.weight-summary"
    static let addWeightWidgetKind = "groberg.Scale.add-weight"

    private static let fileName = "WeightWidgetSnapshot.json"
    private static let tintKey = "appTint"

    static func refresh(using entries: [WeightEntry]) {
        let tintRawValue = UserDefaults.standard.string(forKey: tintKey) ?? "blue"
        let snapshot = WeightWidgetSnapshot.make(from: entries, tintRawValue: tintRawValue)
        write(snapshot)
    }

    static func load() -> WeightWidgetSnapshot {
        load(from: snapshotURL())
    }

    static func load(from url: URL?) -> WeightWidgetSnapshot {
        guard
            let url,
            let data = try? Data(contentsOf: url),
            let snapshot = try? decoder.decode(WeightWidgetSnapshot.self, from: data)
        else {
            return .empty
        }

        return snapshot
    }

    @discardableResult
    static func write(_ snapshot: WeightWidgetSnapshot) -> Bool {
        write(snapshot, to: snapshotURL())
    }

    @discardableResult
    static func write(
        _ snapshot: WeightWidgetSnapshot,
        to url: URL?,
        reloadTimelines: Bool = true
    ) -> Bool {
        guard let url else { return false }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: [.atomic])
            if reloadTimelines {
                WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
                WidgetCenter.shared.reloadTimelines(ofKind: addWeightWidgetKind)
            }
            return true
        } catch {
            return false
        }
    }

    private static func snapshotURL(fileManager: FileManager = .default) -> URL? {
        guard let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }

        return containerURL.appendingPathComponent(fileName, conformingTo: .json)
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
