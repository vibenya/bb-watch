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
    /// Was my message sent after the agent's last reply? Then the agent owes an answer.
    private var awaitingReply: Bool {
        guard let messages = model.stage?.messages, let last = messages.last else { return false }
        return last.role == "user"
    }

    var mood: Mood {
        if !model.connected { return .offline }
        if let delivery { return delivery.state == .failed ? .error : .sending }
        if question != nil || pendingAnswer != nil { return .needsYou }
        if model.stage?.working == true || thread?.status == "active" || awaitingReply { return .working }
        if model.stage?.failed == true || thread?.status == "error" { return .error }
        if lastReply != nil { return .done }
        return .idle
    }
    private var activityLine: String? {
        if let delivery { return delivery.state == .failed ? (delivery.error ?? "Send failed") : statusLabel(delivery.state) }
        if mood == .working { return model.stage?.activity ?? "Thinking" }
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
                    if model.stage?.working == true || mood == .sending { PulseDot(color: mood.tint) }
                }
                Text(mood.word)
                    .font(.poster(34)).foregroundStyle(mood.tint)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .contentTransition(.interpolate)
                    .id(mood.word)
                    .transition(.blurReplace)
                if let activityLine {
                    Text(activityLine).font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary).lineLimit(2)
                        .transition(.blurReplace).id(activityLine)
                }
                Spacer(minLength: 6)
                content
                Spacer(minLength: 0)
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
    }

    @ViewBuilder private var content: some View {
        if thread == nil {
            Text(model.connected ? "Swipe right, choose a chat.\nSwipe left to record." : "Hold to connect BB.")
                .font(.system(size: 15, weight: .semibold).width(.condensed)).foregroundStyle(.secondary)
        } else if let pendingAnswer {
            AnswerUndo(answer: pendingAnswer)
        } else if let question {
            QuestionBlock(question: question)
        } else if let text = lastReply?.text, mood != .sending {
            Text(text.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.system(size: 15, weight: .medium)).lineLimit(6).fixedSize(horizontal: false, vertical: true)
                .transition(.blurReplace).id(lastReply?.id)
        } else if let mine = lastMine?.text {
            Text("“\(mine.trimmingCharacters(in: .whitespacesAndNewlines))”")
                .font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary).lineLimit(4).italic()
        }
    }
}

struct PulseDot: View {
    var color: Color
    @State private var on = false
    var body: some View {
        Circle().fill(color).frame(width: 9, height: 9)
            .scaleEffect(on ? 1.25 : 0.8).opacity(on ? 1 : 0.45)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}

/// Single-choice question rendered as glass capsules; a tap starts the persisted 10 s intent.
private struct QuestionBlock: View {
    @EnvironmentObject var model: AppModel
    let question: BBQuestion
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text(question.prompt).font(.system(size: 14, weight: .medium)).lineLimit(5)
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
}

/// The ten-second cancel window after choosing an option.
private struct AnswerUndo: View {
    @EnvironmentObject var model: AppModel
    let answer: PendingAnswer
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(answer.choiceLabel ?? answer.choice).font(.system(size: 16, weight: .bold)).lineLimit(3)
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
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let title = model.currentThread?.displayTitle { Kicker(text: title) }
                let messages = (model.stage?.messages ?? []).reversed()
                ForEach(Array(messages)) { message in
                    VStack(alignment: .leading, spacing: 4) {
                        if message.role == "assistant" {
                            Text(message.text).font(.system(size: 15, weight: .medium))
                            PlaybackControls(player: model.playback, sourceID: message.id) { model.playback.speak(message.text) }
                        } else {
                            Text(message.text).font(.system(size: 14)).foregroundStyle(.secondary)
                        }
                    }
                }
                if messages.isEmpty { Text("Nothing here yet").foregroundStyle(.secondary) }
            }.padding(.horizontal, 4)
        }
        .containerBackground(.black.gradient, for: .navigation)
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
