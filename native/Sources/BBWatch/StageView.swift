import SwiftUI

/// Centre page. One thread, one big word, the agent's latest words. No chrome.
struct StageView: View {
    @EnvironmentObject var model: AppModel
    @State private var showFull = false
    @State private var showSettings = false

    private var thread: BBThread? { model.currentThread }
    private var question: BBQuestion? { model.questions.first { $0.threadID == model.currentThreadID } }
    private var pendingAnswer: PendingAnswer? { model.pending.first { $0.threadID == model.currentThreadID && $0.status != .accepted } }
    /// The newest unfinished delivery to this thread, if any.
    private var delivery: RecordingDraft? {
        model.drafts.filter { [.queued, .transcribing, .checkingDelivery, .failed].contains($0.state) }
            .filter { if case .thread(let id) = $0.destination { return id == model.currentThreadID }; if case .project = $0.destination { return true }; return false }
            .max { ($0.enqueuedAt ?? .distantPast) < ($1.enqueuedAt ?? .distantPast) }
    }
    private var lastReply: BBMessage? { model.stage?.messages.last { $0.role == "assistant" } }
    private var lastMine: BBMessage? { model.stage?.messages.last { $0.role == "user" } }

    var mood: Mood {
        if !model.connected { return .offline }
        if let delivery { return delivery.state == .failed ? .error : .sending }
        if pendingAnswer != nil { return .needsYou }
        if model.stageSyncFailed { return .syncFailed }
        if model.currentThreadID != nil && model.stage?.status == nil { return .loading }
        if question != nil { return .needsYou }
        if model.stage?.failed == true { return .error }
        if model.stage?.working == true { return .working }
        if model.stage?.status == "waiting-for-host" { return .waiting }
        if lastReply != nil { return .done }
        return .idle
    }
    private var activityLine: String? {
        if let delivery { return delivery.state == .failed ? (delivery.error ?? "Send failed") : statusLabel(delivery.state) }
        if mood == .syncFailed { return "Could not update. Showing saved messages." }
        if mood == .loading { return lastReply == nil ? "Loading conversation" : "Updating saved messages" }
        if mood == .waiting { return "Waiting for BB host" }
        if mood == .working { return model.stage?.activity ?? "Agent is working" }
        if mood == .offline { return "Swipe right, open Settings to connect" }
        return nil
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Stage(mood: mood)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Kicker(text: model.projects.first { $0.id == thread?.projectId }?.name ?? "BB")
                    Spacer(minLength: 4)
                    if mood == .working || mood == .sending || mood == .loading { PulseDot(color: mood.tint) }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(mood.word)
                        .font(.poster(34)).foregroundStyle(mood.tint)
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .contentTransition(.interpolate)
                        .id(mood.word)
                        .transition(.blurReplace)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(mood.word.capitalized)
                if let pendingAnswer {
                    AnswerUndo(answer: pendingAnswer)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            if let activityLine {
                                Text(activityLine).font(.footnote.weight(.medium)).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .transition(.blurReplace).id(activityLine)
                            }
                            content
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .id(model.currentThreadID)
                }
                if let thread {
                    Text(thread.displayTitle).font(.system(size: 12, weight: .semibold).width(.condensed)).foregroundStyle(.tertiary).lineLimit(1)
                }
            }
            .padding(.horizontal, 10).padding(.top, 10).padding(.bottom, 12)
            .animation(.easeInOut(duration: 0.45), value: mood)
            .animation(.easeInOut(duration: 0.45), value: activityLine)
        }
        .onTapGesture { if thread != nil { showFull = true } }
        .onLongPressGesture { showSettings = true }
        .sheet(isPresented: $showFull) { ThreadSheet() }
        .sheet(isPresented: $showSettings) { SettingsSheet() }
        .sensoryFeedback(.success, trigger: lastReply?.id)
        .sensoryFeedback(.warning, trigger: question?.id)
        .sensoryFeedback(.success, trigger: deliveredID)
        .sensoryFeedback(.error, trigger: failedID)
    }

    private func toCurrent(_ draft: RecordingDraft) -> Bool {
        if case .thread(let id) = draft.destination { return id == model.currentThreadID }
        if case .project = draft.destination { return true }
        return false
    }
    /// Newest delivery that reached .accepted in the last 10 min; the window keeps a launch-time reload of old drafts silent.
    private var deliveredID: UUID? {
        model.drafts.filter { $0.state == .accepted && toCurrent($0) && Date().timeIntervalSince($0.enqueuedAt ?? .distantPast) < 600 }
            .max { ($0.enqueuedAt ?? .distantPast) < ($1.enqueuedAt ?? .distantPast) }?.id
    }
    private var failedID: UUID? { delivery?.state == .failed ? delivery?.id : nil }

    @ViewBuilder private var content: some View {
        if thread == nil {
            Text(model.connected ? "Swipe right, choose a chat.\nSwipe left to record." : "Hold to connect BB.")
                .font(.system(size: 15, weight: .semibold).width(.condensed)).foregroundStyle(.secondary)
        } else if let question {
            QuestionBlock(question: question)
        } else if let text = lastReply?.text, mood != .sending {
            Text(text.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.body.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                .transition(.blurReplace).id(lastReply?.id)
        } else if let mine = lastMine?.text {
            Text("“\(mine.trimmingCharacters(in: .whitespacesAndNewlines))”")
                .font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary).italic()
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct PulseDot: View {
    var color: Color
    @Environment(\.isLuminanceReduced) private var dimmed
    @State private var on = false
    var body: some View {
        Circle().fill(color).frame(width: 9, height: 9)
            .scaleEffect(on && !dimmed ? 1.25 : 0.8).opacity(on && !dimmed ? 1 : 0.45)
            .animation(dimmed ? nil : .easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: on)
            .accessibilityHidden(true)
            .onAppear { on = true }
    }
}

/// Single-choice question rendered as glass capsules; a tap starts the persisted 10 s intent.
private struct QuestionBlock: View {
    @EnvironmentObject var model: AppModel
    let question: BBQuestion
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(question.prompt).font(.system(size: 14, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
            if question.supported {
                ForEach(question.options) { option in
                    GlassButton(title: option.label, tint: Mood.needsYou.tint) { _ = model.choose(question, option: option); haptic(.click) }
                }
            } else {
                Text("Answer this one in BB, or record a voice note.").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

/// The ten-second cancel window after choosing an option.
private struct AnswerUndo: View {
    @EnvironmentObject var model: AppModel
    let answer: PendingAnswer
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView {
                Text(answer.choiceLabel ?? answer.choice).font(.system(size: 16, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if answer.status == .waiting {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = max(0, Int(ceil(answer.deadline.timeIntervalSince(context.date))))
                    GlassButton(title: remaining > 0 ? "Cancel · \(remaining)" : "Cancel", symbol: "xmark", tint: .white) { model.cancel(answer.id); haptic(.retry) }
                }
            } else {
                Text(answer.status == .failed ? (answer.error ?? "Could not send") : "Sending answer").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

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
                            Text(message.text).font(.system(size: 15, weight: .medium))
                            PlaybackControls(player: model.playback, sourceID: message.id) { model.playback.speak(message.text) }
                        } else {
                            Text(message.text).font(.system(size: 14)).foregroundStyle(.secondary)
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
    @ObservedObject var player: WatchPlayback
    var sourceID: String
    var play: () -> Void
    private var active: Bool { player.sourceID == sourceID }
    var body: some View {
        GlassButton(title: active && player.isPlaying ? "Pause" : "Listen", symbol: active && player.isPlaying ? "pause.fill" : "play.fill") {
            if active && player.isPlaying { player.pause() } else if active && player.isPaused { player.resume() } else { play() }
        }
        if let error = player.error { Text(error).font(.footnote).foregroundStyle(.secondary) }
    }
}
