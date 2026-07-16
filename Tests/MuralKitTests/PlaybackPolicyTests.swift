import Foundation
import Testing
@testable import MuralKit

/// Baseline: everything nominal, plugged in, unlocked desktop.
private func policy(
    presentationMode: String = "desktop",
    activityState: String = "active",
    userPaused: Bool = false,
    alwaysPauseDesktop: Bool = false,
    pauseWhenOccluded: Bool = false,
    desktopOccluded: Bool = false,
    thermalState: ProcessInfo.ThermalState = .nominal,
    isOnBattery: Bool = false,
    batteryLevel: Int = 100,
    displayBrightness: Float = 1.0
) -> PlaybackPolicy {
    PlaybackPolicy.compute(
        presentationMode: presentationMode,
        activityState: activityState,
        userPaused: userPaused,
        alwaysPauseDesktop: alwaysPauseDesktop,
        pauseWhenOccluded: pauseWhenOccluded,
        desktopOccluded: desktopOccluded,
        thermalState: thermalState,
        isOnBattery: isOnBattery,
        batteryLevel: batteryLevel,
        displayBrightness: displayBrightness
    )
}

@Test func nominalDesktopPlaysAtFullRate() {
    #expect(policy() == .full)
}

@Test func userPauseOverridesEverything() {
    #expect(policy(userPaused: true) == .paused)
}

@Test func criticalThermalPausesButFairOnlyReduces() {
    #expect(policy(thermalState: .critical) == .paused)
    #expect(policy(thermalState: .serious) == .minimal)
    #expect(policy(thermalState: .fair) == .reduced)
}

@Test func batteryTiersEscalateAsChargeDrops() {
    #expect(policy(isOnBattery: true, batteryLevel: 100) == .reduced)
    #expect(policy(isOnBattery: true, batteryLevel: 15) == .minimal)
    // Below 10% pauses regardless of whether we're actually on battery.
    #expect(policy(isOnBattery: true, batteryLevel: 5) == .paused)
    #expect(policy(isOnBattery: false, batteryLevel: 5) == .paused)
}

@Test func suspendedOrIdlePauses() {
    #expect(policy(activityState: "suspended") == .paused)
    #expect(policy(presentationMode: "idle") == .paused)
}

@Test func dimmedBacklightPausesEvenThoughDisplayIsAwake() {
    #expect(policy(displayBrightness: 0.0) == .paused)
    #expect(policy(displayBrightness: PowerState.brightnessPauseThreshold - 0.001) == .paused)
    #expect(policy(displayBrightness: PowerState.brightnessPauseThreshold) == .full)
}

@Test func alwaysPauseDesktopSpareTheLockScreen() {
    #expect(policy(presentationMode: "desktop", alwaysPauseDesktop: true) == .paused)
    #expect(policy(presentationMode: "locked", alwaysPauseDesktop: true) == .full)
}

@Test func occlusionIsIgnoredOnTheLockScreen() {
    #expect(policy(presentationMode: "desktop", pauseWhenOccluded: true, desktopOccluded: true) == .paused)
    #expect(policy(presentationMode: "locked", pauseWhenOccluded: true, desktopOccluded: true) == .full)
    // Occluded but the user didn't ask us to care.
    #expect(policy(presentationMode: "desktop", pauseWhenOccluded: false, desktopOccluded: true) == .full)
}

@Test func mostRestrictiveConditionWins() {
    // Battery alone would be .reduced; serious thermal drags it to .minimal.
    #expect(policy(thermalState: .serious, isOnBattery: true) == .minimal)
    // ...and a user pause beats both.
    #expect(policy(userPaused: true, thermalState: .serious, isOnBattery: true) == .paused)
}

@Test func powerStateOverloadMatchesTheExpandedForm() {
    let state = PowerState(
        thermalState: .serious,
        isOnBattery: true,
        batteryLevel: 42,
        displayBrightness: 0.8
    )
    let viaState = PlaybackPolicy.compute(
        presentationMode: "desktop",
        activityState: "active",
        userPaused: false,
        alwaysPauseDesktop: false,
        pauseWhenOccluded: false,
        desktopOccluded: false,
        powerState: state
    )
    #expect(viaState == policy(thermalState: .serious, isOnBattery: true, batteryLevel: 42, displayBrightness: 0.8))
}

@Test func policyTiersAreOrderedFullToPaused() {
    #expect(PlaybackPolicy.full < PlaybackPolicy.reduced)
    #expect(PlaybackPolicy.reduced < PlaybackPolicy.minimal)
    #expect(PlaybackPolicy.minimal < PlaybackPolicy.paused)
}
