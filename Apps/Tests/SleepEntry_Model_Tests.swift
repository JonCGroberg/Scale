import Testing
import Foundation
@testable import Scale

struct SleepEntryModelTests {
    @Test func sleepEntryInitialization() {
        let start = Date()
        let end = start.addingTimeInterval(28800)
        let entry = SleepEntry(
            startDate: start,
            endDate: end,
            duration: 28800,
            source: .appleHealth,
            stage: .deep,
            healthKitUUID: UUID()
        )
        #expect(entry.startDate == start)
        #expect(entry.endDate == end)
        #expect(entry.duration == 28800)
        #expect(entry.source == .appleHealth)
        #expect(entry.stage == .deep)
        #expect(entry.healthKitUUID != nil)
    }

    @Test func sleepEntryDefaultSource() {
        let start = Date()
        let end = start.addingTimeInterval(28800)
        let entry = SleepEntry(startDate: start, endDate: end, duration: 28800)
        #expect(entry.source == .appleHealth)
    }

    @Test func sleepEntryDefaultStageIsUnspecified() {
        let start = Date()
        let end = start.addingTimeInterval(28800)
        let entry = SleepEntry(startDate: start, endDate: end, duration: 28800)
        #expect(entry.stage == .unspecified)
    }

    @Test func sleepEntryStageRoundTrip() {
        let start = Date()
        let end = start.addingTimeInterval(28800)
        let entry = SleepEntry(startDate: start, endDate: end, duration: 28800, stage: .rem)
        #expect(entry.stage == .rem)
        entry.stage = .core
        #expect(entry.stage == .core)
    }

    @Test func sleepEntryAllStages() {
        let start = Date()
        let end = start.addingTimeInterval(28800)
        for stage in [SleepStage.awake, .inBed, .core, .deep, .rem, .unspecified] {
            let entry = SleepEntry(startDate: start, endDate: end, duration: 28800, stage: stage)
            #expect(entry.stage == stage)
        }
    }

    @Test func onlyAsleepStagesCountTowardSleepDuration() {
        #expect(SleepStage.awake.countsTowardSleepDuration == false)
        #expect(SleepStage.inBed.countsTowardSleepDuration == false)
        #expect(SleepStage.core.countsTowardSleepDuration)
        #expect(SleepStage.deep.countsTowardSleepDuration)
        #expect(SleepStage.rem.countsTowardSleepDuration)
        #expect(SleepStage.unspecified.countsTowardSleepDuration)
    }

    @Test func sleepEntryNilUUID() {
        let start = Date()
        let end = start.addingTimeInterval(28800)
        let entry = SleepEntry(startDate: start, endDate: end, duration: 28800)
        #expect(entry.healthKitUUID == nil)
    }

    @Test func sleepEntryStageRawValuePersistence() {
        let start = Date()
        let end = start.addingTimeInterval(28800)
        let entry = SleepEntry(startDate: start, endDate: end, duration: 28800, stage: .deep)
        #expect(entry.stageRawValue == "deep")
    }

    @Test func sleepEntryInvalidStageRawValueFallsBackToUnspecified() {
        let start = Date()
        let end = start.addingTimeInterval(28800)
        let entry = SleepEntry(startDate: start, endDate: end, duration: 28800)
        entry.stageRawValue = "unknown"
        #expect(entry.stage == .unspecified)
    }
}
