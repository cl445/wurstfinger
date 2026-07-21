//
//  LongPressSchedulerTests.swift
//  WurstfingerTests
//
//  Tests for the shared LongPressScheduler extracted from KeyGestureRecognizer
//  and SlideGestureHandler: the synchronous fire/consume core plus the
//  DispatchWorkItem timer wiring. `runFire` is synchronous so the guard path
//  is testable without a real 0.7 s timer.
//

import Foundation
import Testing
@testable import WurstfingerApp

@Suite(.serialized)
struct LongPressSchedulerTests {
    @Test func runFireWithPassingGuardConsumesTouch() {
        let scheduler = LongPressScheduler()
        scheduler.runFire { true }
        #expect(scheduler.consumedTouch)
        #expect(!scheduler.isScheduled)
    }

    @Test func runFireWithFailingGuardDoesNotConsume() {
        let scheduler = LongPressScheduler()
        scheduler.runFire { false }
        #expect(!scheduler.consumedTouch)
    }

    @Test func clearConsumedResetsFlag() {
        let scheduler = LongPressScheduler()
        scheduler.runFire { true }
        #expect(scheduler.consumedTouch)
        scheduler.clearConsumed()
        #expect(!scheduler.consumedTouch)
    }

    @Test func scheduleSetsIsScheduledAndCancelClearsIt() {
        let scheduler = LongPressScheduler()
        // Long delay so the timer never fires during the test — assert only on
        // the synchronous `isScheduled` bookkeeping.
        scheduler.schedule(after: 5) { true }
        #expect(scheduler.isScheduled)
        scheduler.cancel()
        #expect(!scheduler.isScheduled)
    }

    @Test func scheduledWorkItemFiresGuardAndConsumes() async {
        await confirmation { confirmed in
            let scheduler = LongPressScheduler()
            scheduler.schedule(after: 0.02) {
                confirmed()
                return true
            }
            try? await Task.sleep(for: .milliseconds(200))
            #expect(scheduler.consumedTouch)
            #expect(!scheduler.isScheduled)
        }
    }
}
