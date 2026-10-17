import SwiftUI

/// Full thread as a sheet: newest first, agent lines readable and listenable.
struct ThreadSheet: View {
    @EnvironmentObject var model: AppModel
    @State private var history: [BBMessage] = []
    @State private var cursor: BBHistoryCursor?
    @State private var scope: UUID?
    @State private var loading = false
    @State private var historyError: String?
    @State private var reloadRequired = false

    private var messages: [BBMessage] {
        let saved = scope == model.stageRevision ? history : []
        let recent = model.stage?.messages ?? []
        let updates = Dictionary(recent.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        var seen = Set<String>()
        return (saved.map { updates[$0.id] ?? $0 } + recent).filter { seen.insert($0.id).inserted }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let title = model.currentThread?.displayTitle { Kicker(text: title) }
                ForEach(Array(messages.reversed())) { message in
                    VStack(alignment: .leading, spacing: 4) {
                        if message.role == "assistant" {
                            Text(message.text).privacySensitive().font(.glance)
                            PlaybackControls(player: model.playback, sourceID: message.id) { model.playback.speak(message.text, sourceID: message.id) }
                        } else {
                            Text(message.text).privacySensitive().font(.glance).foregroundStyle(.secondary)
                        }
                    }
                }
                if scope == model.stageRevision {
                    if loading { ProgressView("Loading history") }
                    if let historyError { Text(historyError).foregroundStyle(.secondary) }
                    if !loading && (cursor != nil || historyError != nil) {
                        Button(reloadRequired ? "Reload history" : history.isEmpty ? "Retry history" : "Load older") {
                            Task { await loadHistory(before: reloadRequired ? nil : cursor) }
                        }
                    }
                }
                if model.stageSyncFailed {
                    Text("Could not update. Showing saved messages.").foregroundStyle(.secondary)
                } else if model.stage?.status == nil {
                    Text("Loading conversation").foregroundStyle(.secondary)
                } else if messages.isEmpty && !loading {
                    Text("Nothing here yet").foregroundStyle(.secondary)
                }
            }.padding(.horizontal, 4)
        }
        .containerBackground(.black.gradient, for: .navigation)
        .task(id: model.stageRevision) {
            scope = model.stageRevision
            history = []; cursor = nil; historyError = nil; reloadRequired = false; loading = false
            await loadHistory(before: nil)
        }
    }

    @MainActor private func loadHistory(before: BBHistoryCursor?) async {
        guard !model.isFixture else { return }
        let expected = model.stageRevision
        guard scope == expected, !loading, let threadID = model.currentThreadID else { return }
        loading = true; historyError = nil
        defer { if scope == expected && model.stageRevision == expected { loading = false } }
        do {
            let page = try await model.client.history(threadID: threadID, before: before)
            try Task.checkCancellation()
            guard scope == expected, model.stageRevision == expected else { return }
            // The latest page wins at overlapping boundaries. Older pages are prepended
            // in server order; stage polling updates the tail without dropping history.
            var seen = Set<String>()
            let existing = Set(history.map(\.id))
            history = before == nil ? page.messages : page.messages.filter { !existing.contains($0.id) } + history
            history = history.filter { seen.insert($0.id).inserted }
            cursor = page.olderCursor; reloadRequired = false
        } catch {
            guard scope == expected, model.stageRevision == expected, !Task.isCancelled else { return }
            if case BBClientError.http(400) = error, before != nil {
                reloadRequired = true
                historyError = "History changed. Reload to continue."
            } else {
                historyError = "Could not load history. Try again."
            }
        }
    }
}

struct PlaybackControls: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var player: WatchPlayback
    var sourceID: String
    var play: () -> Void
    private var active: Bool { player.sourceID == sourceID }
    var body: some View {
        GlassButton(title: active && (player.isPlaying || player.isPreparing) ? "Pause" : "Listen", symbol: active && (player.isPlaying || player.isPreparing) ? "pause.fill" : "play.fill") {
            if active && (player.isPlaying || player.isPreparing) { player.pause() } else if active && player.isPaused { player.resume() } else { play() }
        }
        .disabled(model.captureIsRecording || model.captureStarting)
        if active, let error = player.error { Text(error).font(.footnote).foregroundStyle(.secondary) }
    }
}
