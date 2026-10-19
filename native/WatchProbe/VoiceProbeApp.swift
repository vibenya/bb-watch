import SwiftUI

@main struct VoiceProbeApp: App {
    @WKApplicationDelegateAdaptor(ProbeApplicationDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = ProbeModel.shared
    init() { _ = BackgroundProbe.shared }
    var body: some Scene {
        WindowGroup {
            ProbeView(model: model)
                .onChange(of: scenePhase, initial: true) { _, phase in model.scene(phase) }
        }
    }
}
struct ProbeView: View {
    @Bindable var model: ProbeModel
    @State private var armedAt = Date()
    private var transient: Bool { ![.ready, .live, .stopped, .blocked].contains(model.state) }
    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 2) {
                ForEach(Array(model.levels.enumerated()), id: \.offset) { _, level in
                    Rectangle().frame(width: 3, height: max(1, CGFloat(min(level, 1)) * 38))
                }
            }.frame(height: 40).opacity(model.state == .stopped ? 0.5 : 1)
            HStack {
                Color.clear.frame(width: 34, height: 44)
                Button {
                    guard Date() > armedAt else { return }
                    if model.state == .blocked { model.retry() }
                    else if model.state == .live { model.finish(enqueue: false) }
                    else { model.start() }
                } label: {
                    Image(systemName: model.state == .blocked ? "arrow.clockwise" : model.state == .live ? "stop.fill" : model.state == .stopped ? "circle.fill" : "mic.fill")
                        .frame(width: 44, height: 44)
                        .foregroundStyle(model.state == .stopped || model.state == .live ? Color.white : Color.black)
                }
                .buttonStyle(.borderedProminent)
                .tint(model.state == .stopped ? .red : model.state == .live ? .gray : Color(red: 0.78, green: 1, blue: 0.2))
                .accessibilityLabel(model.state == .blocked ? "Retry local recovery" : model.state == .live ? "Stop and save" : model.state == .stopped ? "Continue recording" : "Record")
                Button {
                    guard Date() > armedAt else { return }
                    model.finish(enqueue: true)
                } label: { Image(systemName: "return").frame(width: 34, height: 44) }
                    .tint(.green).disabled(model.state != .live && model.state != .stopped)
                    .accessibilityLabel("Stage recording locally")
            }.id(model.state).disabled(transient)
            if transient { ProgressView().accessibilityLabel("Local transition") }
            Label("BB", systemImage: "arrow.triangle.branch")
            if let text = Bundle.main.object(forInfoDictionaryKey: "ProbeLoopbackFixtureURL") as? String,
               let url = URL(string: text) {
                Button("Fixture upload") { BackgroundProbe.shared.uploadSyntheticFixture(to: url) }
                    .disabled(transient || model.state == .live)
            }
            if let issue = model.issue { Text(issue).font(.caption2) }
        }
        // Probe has no discard, Threads, pairing, playback, timer or production Send.
        .onChange(of: model.state) { _, _ in armedAt = Date().addingTimeInterval(0.4) }
    }
}
