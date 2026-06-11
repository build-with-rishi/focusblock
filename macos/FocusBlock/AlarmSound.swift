import AppKit

// Selects and loads the alarm ringtone played while an overlay is up.
// Uses the native macOS/iOS alarm ringtones from ToneLibrary; that path is
// private and could move in a future macOS, so loading falls back to any
// available ringtone, then to the Sosumi system alert.
enum AlarmSound {
    private static let ringtonesDirectory =
        "/System/Library/PrivateFrameworks/ToneLibrary.framework/Versions/A/Resources/Ringtones"

    static let defaultName = "Radar"

    private static let curated = [
        "Radar", "Reflection", "Apex", "Beacon", "Presto", "Sencha",
        "Signal", "Sonar", "Slow Rise", "Waves", "Summit", "Uplift"
    ]

    private static let selectionKey = "alarmRingtone"
    private static var previewSound: NSSound?

    static var selectedName: String {
        get { UserDefaults.standard.string(forKey: selectionKey) ?? defaultName }
        set { UserDefaults.standard.set(newValue, forKey: selectionKey) }
    }

    static func availableNames() -> [String] {
        curated.filter { FileManager.default.fileExists(atPath: path(for: $0)) }
    }

    static func makeSound() -> NSSound? {
        let fallbacks = ((try? FileManager.default.contentsOfDirectory(atPath: ringtonesDirectory)) ?? [])
            .filter { $0.hasSuffix(".m4r") }
            .map { "\(ringtonesDirectory)/\($0)" }

        for soundPath in [path(for: selectedName), path(for: defaultName)] + fallbacks {
            if FileManager.default.fileExists(atPath: soundPath),
               let sound = NSSound(contentsOfFile: soundPath, byReference: true) {
                return sound
            }
        }
        return NSSound(named: "Sosumi")
    }

    static func preview() {
        previewSound?.stop()
        previewSound = makeSound()
        previewSound?.play()
    }

    static func stopPreview() {
        previewSound?.stop()
        previewSound = nil
    }

    private static func path(for name: String) -> String {
        "\(ringtonesDirectory)/\(name).m4r"
    }
}
