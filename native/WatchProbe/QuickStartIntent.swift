import AppIntents

struct StartVoiceProbe: AppIntent {
    static let title: LocalizedStringResource = "Record with Voice Probe"
    static let description = IntentDescription("Start or append in the current voice context. Does not send.")
    static var supportedModes: IntentModes { .foreground(.immediate) }
    static var authenticationPolicy: IntentAuthenticationPolicy { .requiresLocalDeviceAuthentication }
    @MainActor func perform() async throws -> some IntentResult {
        ProbeModel.shared.quickStart()
        return .result()
    }
}
struct ProbeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartVoiceProbe(), phrases: ["Record with \(.applicationName)"], shortTitle: "Record", systemImageName: "mic.fill")
    }
}
