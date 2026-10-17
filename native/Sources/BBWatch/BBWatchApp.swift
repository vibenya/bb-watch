import SwiftUI

@main
struct BBWatchApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(model).modifier(FixtureAccessibility(enabled: model.isFixture))
                .alert("BB", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                    Button("OK", role: .cancel) { model.error = nil }
                } message: { Text(model.error ?? "") }
                .onChange(of: phase, initial: true) { _, next in
                    model.foreground = next == .active
                    let event: DiagnosticEvent = next == .active ? .sceneActive : next == .background ? .sceneBackground : .sceneInactive
                    Task { await WatchDiagnostics.shared.record(event, foreground: next == .active) }
                }
        }
    }
}
private struct StagePollKey: Equatable {
    let revision: UUID; let identity: String; let threadID: String?; let foreground: Bool; let sending: Bool
}
private struct SidebarPollKey: Equatable { let identity: String; let foreground: Bool }
enum GlanceSheet: String, Identifiable {
    case threads, projects, models, recordings, detail, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .threads: "Threads"
        case .projects: "Project"
        case .models: "Model"
        case .recordings: "Recordings"
        case .detail: "Conversation"
        case .settings: "Settings"
        }
    }
}
struct RootView: View {
    @EnvironmentObject var model: AppModel
    @State private var sheet: GlanceSheet?
    var body: some View {
        NavigationStack {
            GlanceView(recorder: model.recorder, sheet: $sheet)
                .toolbar(.hidden, for: .navigationBar)
        }
        .tint(GlanceStyle.lime)
        .sheet(item: $sheet) { destination in
            NavigationStack {
                Group {
                    switch destination {
                    case .threads: ThreadsView()
                    case .projects: ProjectPicker()
                    case .models: ModelPicker()
                    case .recordings: RecordingsSheet()
                    case .detail: ThreadSheet()
                    case .settings: SettingsSheet()
                    }
                }
                .privacySensitive()
                .navigationTitle(destination.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            model.recorderPresented = true
                            sheet = nil
                        } label: { Image(systemName: model.captureIsRecording ? "mic.fill" : "mic") }
                        .tint(GlanceStyle.surface)
                        .foregroundStyle(model.captureIsRecording ? .red : GlanceStyle.lime)
                        .accessibilityLabel("Return to recorder")
                        .accessibilityValue(model.captureIsRecording ? "Recording" : "Microphone is paused")
                    }
                }
            }
            .tint(GlanceStyle.lime)
        }
        .task(id: StagePollKey(revision: model.stageRevision, identity: model.identity, threadID: model.currentThreadID, foreground: model.foreground, sending: !model.sending.isEmpty)) { await model.watchStage() }
        .task(id: SidebarPollKey(identity: model.identity, foreground: model.foreground)) { await model.watchSidebar() }
        .onOpenURL { url in
            guard url.scheme == "bbwatch", url.host == "record" else { return }
            sheet = nil; model.recorderPresented = true
            guard model.activeID == nil, !model.captureStarting else { return }
            Task { await model.start(destination: model.recordTarget) }
        }
    }
}

struct SettingsSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var pairing = false
    var body: some View {
        List {
            if model.connected { Label("Connected", systemImage: "checkmark.circle").foregroundStyle(GlanceStyle.lime) }
            Section(model.connected ? "Re-pair" : "Connect BB") {
                Text("BB → Settings → Mobile → Add mobile device. Enter the code.").font(.footnote).foregroundStyle(.secondary)
                TextField("Pairing code", text: $code)
                Button(pairing ? "Connecting…" : "Connect") {
                    pairing = true
                    Task { await model.pair(code: code); code = ""; pairing = false; if model.connected { dismiss() } }
                }.disabled(code.isEmpty || pairing || model.captureIsRecording || model.captureStarting || !model.sending.isEmpty || model.isFixture)
            }
            if let sync = model.lastSync { Text("Synced \(sync.formatted(date: .omitted, time: .shortened))").font(.footnote).foregroundStyle(.secondary) }
        }.containerBackground(.black, for: .navigation)
    }
}

struct RecordingsSheet: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        List {
            ForEach(model.drafts.reversed()) { draft in
                NavigationLink { DraftDetail(id: draft.id) } label: { RecordingRow(draft: draft) }
            }
            if model.drafts.isEmpty { Text("Your recordings will appear here.").foregroundStyle(.secondary) }
        }.containerBackground(.black, for: .navigation)
    }
}
struct RecordingRow: View {
    @EnvironmentObject var model: AppModel
    let draft: RecordingDraft
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(model.recordingTopic(draft)).privacySensitive().font(.glance).lineLimit(2)
                Text(model.destinationLabel(draft)).privacySensitive().font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                Text(draft.creatingRequestID != nil ? "Waiting for new thread" : draft.state == .checkingDelivery && model.sending.contains(draft.id) ? "Sending transcript" : statusLabel(draft.state)).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: GlancePresentation.symbol(draft.state, sending: model.sending.contains(draft.id)))
                .foregroundStyle(GlanceStyle.lime).accessibilityHidden(true)
        }.padding(.vertical, 3)
    }
}
struct DraftDetail: View {
    @EnvironmentObject var model: AppModel
    let id: UUID
    @State private var deleting = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            if let value = model.draft(id) {
                Text(model.destinationLabel(value)).font(.headline)
                Text(statusLabel(value.state)).font(.glance)
                Text(durationLabel(value.duration)).font(.caption).foregroundStyle(.secondary)
                if value.recoveryIssue != nil {
                    Text("Audio was found after an interruption. Review recovered parts before sending.").font(.footnote)
                    Button("Review and recover") { model.recover(id) }.disabled(model.activeID == id)
                }
                if let error = value.error { Text(error).font(.footnote).foregroundStyle(.secondary) }
                if !value.chunks.isEmpty {
                    PlaybackControls(player: model.playback, sourceID: id.uuidString) {
                        do { if let store = model.store { model.playback.play(chunks: value.chunks, directory: try store.chunksDirectory(for: id)) } }
                        catch { model.error = error.localizedDescription }
                    }
                }
                if value.state == .queued && !model.sending.contains(id) { Button("Cancel queued send") { model.cancelQueue(id) } }
                if (value.state == .draft || value.state == .failed) && value.recoveryIssue == nil {
                    if value.destination != nil {
                        IconAction(symbol: "arrow.up", label: "Send recording", prominent: true) { Task { await model.deliver(id) }; dismiss() }
                            .disabled(model.activeID != nil && model.activeID != id)
                    }
                    Button("Open recording", systemImage: "waveform") {
                        model.reopen(id); dismiss()
                    }.disabled(model.activeID != nil)
                }
                if let transcript = value.transcript { Text(transcript).font(.glance) }
                if value.state == .checkingDelivery { Text("Delivery is unconfirmed. Check the conversation. Automatic retry is paused to avoid a duplicate.").font(.footnote) }
                if !model.sending.contains(id) && value.state != .checkingDelivery && model.activeID != id {
                    Button("Delete", role: .destructive) { deleting = true }
                }
            } else { Text("Recording unavailable") }
        }
        .containerBackground(.black, for: .navigation)
        .privacySensitive()
        .confirmationDialog("Delete recording from this watch?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete recording", role: .destructive) {
                do { try model.store?.deleteDraft(id: id); model.reload(); dismiss() } catch { model.error = error.localizedDescription }
            }
        }
    }
}

private struct FixtureAccessibility: ViewModifier {
    let enabled: Bool
    @ViewBuilder func body(content: Content) -> some View {
        #if DEBUG && targetEnvironment(simulator)
        if enabled && ProcessInfo.processInfo.environment["BB_UI_ACCESSIBILITY"] == "1" {
            content.dynamicTypeSize(.accessibility3)
        } else { content }
        #else
        content
        #endif
    }
}
