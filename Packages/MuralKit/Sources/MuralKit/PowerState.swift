import Foundation

/// Snapshot of the power and display conditions that gate playback.
///
/// A plain value type so `PlaybackPolicy` stays testable without IOKit;
/// `PowerMonitor` in the extension owns the job of keeping it current.
public struct PowerState: Equatable, Sendable {
    public var thermalState: ProcessInfo.ThermalState
    public var isOnBattery: Bool
    public var batteryLevel: Int
    /// Backlight brightness of the built-in display, 0.0–1.0. Defaults to 1.0
    /// when the value can't be read (external displays, headless, etc.).
    public var displayBrightness: Float

    public init(
        thermalState: ProcessInfo.ThermalState = .nominal,
        isOnBattery: Bool = false,
        batteryLevel: Int = 100,
        displayBrightness: Float = 1.0
    ) {
        self.thermalState = thermalState
        self.isOnBattery = isOnBattery
        self.batteryLevel = batteryLevel
        self.displayBrightness = displayBrightness
    }

    public var shouldPause: Bool {
        if thermalState == .critical || thermalState == .serious { return true }
        if isOnBattery, batteryLevel < 20 { return true }
        if displayBrightness < Self.brightnessPauseThreshold { return true }
        return false
    }

    /// Below this brightness, the screen is effectively invisible to the user
    /// even though `screensDidSleepNotification` hasn't fired. We treat this
    /// as paused so the renderer stops burning battery.
    public static let brightnessPauseThreshold: Float = 0.05
}
