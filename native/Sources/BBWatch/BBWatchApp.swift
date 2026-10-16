import SwiftUI

enum Page: Hashable { case record, stage, threads }

@main
struct BBWatchApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(model)
                .alert("BB", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                    Button("OK", role: .cancel) { model.error = nil }
                } message: { Text(model.error ?? "") }
                .onChange(of: phase) { _, next in
                    if next == .active { Task { await model.refresh(); model.adoptDefaultThread() } }
                }
        }
    }
}

/// Three pages, horizontal like Workout: Record ← Stage → Threads. The stage is home.
struct RootView: View {
    @EnvironmentObject var model: AppModel
    @State private var page: Page = .stage
    var body: some View {
        TabView(selection: $page) {
            RecordView(recorder: model.recorder, page: $page).tag(Page.record)
            StageView().tag(Page.stage)
            ThreadsView(page: $page).tag(Page.threads)
        }
        .tabViewStyle(.page)
        .background(Color.black.ignoresSafeArea())
        .task {
            await model.refresh(); model.adoptDefaultThread()
            await model.watchStage()
        }
        .onOpenURL { url in
            // Complication tap: jump to the recorder and start on the current thread.
            guard url.scheme == "bbwatch", url.host == "record" else { return }
            withAnimation(.snappy) { page = .record }
            guard !model.recorder.isRecording, let target = model.recordTarget else { return }
            Task { await model.start(destination: target) }
        }
        .onChange(of: model.activeID) { _, id in if id != nil { withAnimation(.snappy) { page = .record } } }
        // Any send in flight belongs on the stage, wherever it was started.
        .onChange(of: model.sending.isEmpty) { _, idle in if !idle { withAnimation(.snappy) { page = .stage } } }
        .onChange(of: model.questions.map(\.id)) { _, _ in
            // A question for the current thread pulls the stage into view.
            if model.questions.contains(where: { $0.threadID == model.currentThreadID }) { withAnimation(.snappy) { page = .stage } }
        }
    }
}

/// Pairing lives behind a long press on the stage and in the threads footer; nothing else needs settings.
struct SettingsSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var pairing = false
    var body: some View {
        List {
            if model.connected {
                Label("Connected", systemImage: "checkmark.circle.fill").foregroundStyle(Mood.working.tint)
                Text(URL(string: model.connection.serverURL)?.host ?? "").font(.footnote).foregroundStyle(.secondary)
            }
            Section(model.connected ? "Re-pair" : "Connect BB") {
                Text("BB → Settings → Mobile → Add mobile device. Enter the code.").font(.footnote).foregroundStyle(.secondary)
                TextField("Pairing code", text: $code)
                Button(pairing ? "Connecting…" : "Connect") {
                    pairing = true
                    Task { await model.pair(code: code); code = ""; pairing = false; if model.connected { dismiss() } }
                }.disabled(code.isEmpty || pairing || model.recorder.isRecording || !model.sending.isEmpty)
            }
            if let sync = model.lastSync { Text("Synced \(sync.formatted(date: .omitted, time: .shortened))").font(.footnote).foregroundStyle(.secondary) }
        }.containerBackground(.black.gradient, for: .navigation)
    }
}

/// Unsent audio kept on the watch. Send, continue, or delete.
struct RecordingsSheet: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        NavigationStack { List {
            ForEach(model.drafts.filter { $0.state != .accepted }.reversed()) { draft in
                NavigationLink { DraftDetail(id: draft.id) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(durationLabel(draft.duration)) · \(statusLabel(draft.state))").font(.system(size: 15, weight: .semibold))
                        Text(draft.createdAt, format: .dateTime.day().month().hour().minute()).font(.kicker).foregroundStyle(.secondary)
                    }
                }
            }
            if model.drafts.allSatisfy({ $0.state == .accepted }) { Text("Everything is sent").foregroundStyle(.secondary) }
        }.containerBackground(.black.gradient, for: .navigation) }
    }
}

struct DraftDetail: View {
    @EnvironmentObject var model: AppModel
    let id: UUID
    @State private var deleting = false
    @State private var picker = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            if let value = model.draft(id) {
                Text(durationLabel(value.duration)).font(.poster(30).monospacedDigit())
                Text(statusLabel(value.state)).foregroundStyle(.secondary)
                if value.recoveryIssue != nil {
                    Text("Audio was found after an interruption. Review recovered parts before sending.").font(.footnote)
                    Button("Review and recover") { model.recover(id) }
                }
                if let error = value.error { Text(error).font(.footnote).foregroundStyle(.secondary) }
                if !value.chunks.isEmpty {
                    PlaybackControls(player: model.playback, sourceID: id.uuidString) {
                        do { if let store = model.store { model.playback.play(chunks: value.chunks, directory: try store.chunksDirectory(for: id)) } }
                        catch { model.error = error.localizedDescription }
                    }
                }
                if value.state == .queued && !model.sending.contains(id) { Button("Cancel queued send") { model.cancelQueue(id) } }
                if value.state == .draft || value.state == .failed {
                    Button("Send", systemImage: "arrow.up") {
                        if let target = value.destination ?? model.recordTarget { Task { await model.deliver(id, destination: target) } } else { picker = true }
                    }.listItemTint(Mood.working.tint.opacity(0.35))
                    Button("Continue recording", systemImage: "mic") { Task { await model.start(existing: id) }; dismiss() }
                }
                if let transcript = value.transcript { Text(transcript).font(.footnote) }
                if value.state == .checkingDelivery { Text("Delivery is unconfirmed. Check the thread before retrying to avoid a duplicate.").font(.footnote) }
                if !model.sending.contains(id) && value.state != .checkingDelivery {
                    Button("Delete", role: .destructive) { deleting = true }
                }
            } else { Text("Recording unavailable") }
        }
        .containerBackground(.black.gradient, for: .navigation)
        .sheet(isPresented: $picker) { TargetPicker() }
        .confirmationDialog("Delete recording from this watch?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete recording", role: .destructive) {
                do { try model.store?.deleteDraft(id: id); model.reload(); dismiss() } catch { model.error = error.localizedDescription }
            }
        }
    }
}
