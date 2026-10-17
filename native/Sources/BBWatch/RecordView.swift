import SwiftUI
import Accessibility

struct GlanceView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var recorder: WatchRecorder
    @Binding var sheet: GlanceSheet?
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool {
        #if DEBUG && targetEnvironment(simulator)
        systemReduceMotion || (model.isFixture && ProcessInfo.processInfo.environment["BB_UI_ACCESSIBILITY"] == "1")
        #else
        systemReduceMotion
        #endif
    }
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.isLuminanceReduced) private var dimmed
    @ScaledMetric(relativeTo: .callout) private var bodyHeight = 72.0
    @ScaledMetric(relativeTo: .callout) private var textSize = 16.0
    private var blockRevision: String {
        if capturing { return "capture-\(model.activeID!.uuidString)-\(model.captureIsRecording)-\(model.captureStarting)" }
        if let pending { return "answer-\(pending.id)-\(pending.status.rawValue)" }
        if let question { return "question-\(question.id)-\(question.prompt)" }
        return contextIsNew && model.currentDelivery == nil ? "new" : model.recorderPresented ? "recorder" : "content"
    }
    private var question: BBQuestion? {
        guard !contextIsNew else { return nil }
        return model.questions.first { $0.threadID == model.currentThreadID }
    }
    private var pending: PendingAnswer? {
        guard !contextIsNew else { return nil }
        return model.pending.first { $0.threadID == model.currentThreadID && $0.status != .accepted }
    }
    private var capturing: Bool { model.activeID != nil }
    private var presentation: GlancePresentation { model.presentation }
    private var contextIsNew: Bool {
        if capturing { if case .project = model.activeDraft?.destination { return true }; return model.activeDraft?.destination == nil }
        return model.newThreadMode
    }
    private var headerSymbol: String {
        if capturing { return model.captureIsRecording ? "mic.fill" : "pause.circle" }
        if model.newThreadMode && model.currentDelivery == nil { return "plus.circle" }
        if question != nil || pending != nil { return "questionmark.circle" }
        return presentation.symbol
    }
    private var announcement: String {
        if capturing { return model.captureStarting ? "Starting microphone" : model.captureIsRecording ? "Recording" : "Recording paused" }
        if let pending { return pending.status == .waiting ? "Answer selected. Undo is available for ten seconds." : pending.error == nil ? "Sending answer" : "Answer delivery unconfirmed" }
        if question != nil && model.currentDelivery == nil { return "Question from BB" }
        if contextIsNew && model.currentDelivery == nil { return "New thread" }
        return presentation.status
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Button { sheet = .threads } label: {
                    HStack(spacing: 9) {
                        Image(systemName: headerSymbol).font(.title3)
                            .foregroundStyle(capturing ? .red : GlanceStyle.lime)
                            .contentTransition(reduceMotion ? .opacity : .symbolEffect(.replace))
                            .frame(width: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.contextTitle).privacySensitive().font(.glance.weight(.medium)).lineLimit(1)
                            if let timestamp = model.contextThread?.updatedAt {
                                Text(relativeLabel(timestamp)).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(.horizontal, 9).contentShape(Rectangle())
                }
                .buttonStyle(.plain).background(GlanceStyle.surface, in: RoundedRectangle(cornerRadius: 15))
                .accessibilityLabel("Choose thread")
                .accessibilityValue(model.contextTitle + ", " + (capturing ? (model.captureIsRecording ? "Recording" : "Paused") : contextIsNew && model.currentDelivery == nil ? "New thread" : presentation.status))
                .animation(reduceMotion || dimmed ? nil : .easeInOut(duration: 0.2), value: headerSymbol)

                if capturing {
                    captureBlock.transition(.opacity)
                    if contextIsNew && model.activeDraft?.creatingRequestID == nil {
                        newContext
                    }
                } else {
                    if contextIsNew && model.currentDelivery == nil { newContext }
                    else if model.recorderPresented {
                        Text("Ready when you are.").font(.glance).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: bodyHeight, alignment: .leading)
                    } else {
                        workingBlock
                            .frame(maxWidth: .infinity, minHeight: bodyHeight, alignment: .topLeading)
                    }
                    IconAction(symbol: "mic.fill", label: question == nil ? "Record" : "Record voice", prominent: true) {
                        Task { await model.start(destination: model.recordTarget) }
                    }.disabled(model.captureStarting)
                }
                Button { sheet = .recordings } label: {
                    HStack { Text("Recordings"); Spacer(); Image(systemName: "chevron.right") }.font(.caption).foregroundStyle(.secondary).frame(minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain)
                ForEach(Array(model.drafts.reversed().prefix(5))) { draft in
                    NavigationLink { DraftDetail(id: draft.id) } label: { RecordingRow(draft: draft).padding(9).contentShape(Rectangle()) }
                        .buttonStyle(.plain).background(GlanceStyle.surface, in: RoundedRectangle(cornerRadius: 14))
                }
                #if DEBUG && targetEnvironment(simulator)
                if model.fixtureScenario == "lifecycle" {
                    Button("Advance fixture") { model.advanceFixture() }.accessibilityIdentifier("Advance fixture")
                }
                #endif
                HStack {
                    Button { sheet = .detail } label: { Image(systemName: "text.bubble").frame(maxWidth: .infinity, minHeight: 44) }
                        .accessibilityLabel("Full conversation").disabled(model.currentThreadID == nil)
                    Button { sheet = .settings } label: { Image(systemName: model.connected ? "gearshape" : "link").frame(maxWidth: .infinity, minHeight: 44) }
                        .accessibilityLabel(model.connected ? "Settings" : "Connect BB")
                }.buttonStyle(.bordered).tint(GlanceStyle.surface).foregroundStyle(.white)
            }
            .animation(reduceMotion || dimmed ? nil : .easeInOut(duration: 0.2), value: blockRevision)
            .padding(.horizontal, 8).padding(.top, 2).padding(.bottom, 16)
        }
        .background(Color.black)
        .accessibilityHidden(sheet != nil)
        .onChange(of: announcement) { _, status in
            guard model.foreground, sheet == nil else { return }
            AccessibilityNotification.Announcement(status).post()
        }
        .simultaneousGesture(DragGesture(minimumDistance: 35).onEnded { value in
            if value.translation.width < -55 && abs(value.translation.width) > abs(value.translation.height) * 1.7 { sheet = .threads }
        })
    }
    private var newContext: some View {
        VStack(spacing: 6) {
            selector("Project", value: model.contextProject?.name ?? "Choose project") { sheet = .projects }
            selector("Model", value: model.contextModelName) { sheet = .models }
        }
    }
    private func selector(_ title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.glance)
                    Text(value).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 3)
                Image(systemName: "chevron.right").font(.caption2)
            }.frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).padding(.horizontal, 10).background(GlanceStyle.surface, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(.white).accessibilityIdentifier(title + " selector")
    }
    @ViewBuilder private var workingBlock: some View {
        if let pending { AnswerUndo(answer: pending).transition(.opacity) }
        else if let question, model.currentDelivery == nil { QuestionBlock(question: question).transition(.opacity) }
        else {
            Button { sheet = model.currentDelivery == nil ? .detail : .recordings } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(presentation.text.trimmingCharacters(in: .whitespacesAndNewlines)).privacySensitive()
                        .font(.system(size: textSize, design: .rounded)).lineLimit(typeSize.isAccessibilitySize ? nil : presentation.detail == nil ? 4 : 3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let detail = presentation.detail { Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(typeSize.isAccessibilitySize ? nil : 2).fixedSize(horizontal: false, vertical: true) }
                }
                .contentShape(Rectangle())
                .id(presentation)
                .transition(.opacity)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(presentation.text + (presentation.detail.map { ". " + $0 } ?? ""))
            .accessibilityHint("Opens full text and playback")
            .animation(reduceMotion || dimmed ? nil : .easeInOut(duration: 0.2), value: presentation)
        }
    }
    private var captureBlock: some View {
        VStack(spacing: 8) {
            ZStack {
                Waveform(level: recorder.level, recording: model.captureIsRecording && !dimmed && model.foreground && sheet == nil)
                    .frame(height: 70).accessibilityHidden(true)
                HStack {
                    if !model.captureIsRecording {
                        Button { _ = model.finish() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                            .buttonStyle(.plain).background(GlanceStyle.surface, in: Circle()).foregroundStyle(.white)
                            .accessibilityLabel("Close recording, keep saved audio").disabled(model.captureStarting)
                    } else { Color.clear.frame(width: 44, height: 44) }
                    Spacer(minLength: 2)
                    Button {
                        if model.captureIsRecording { model.pause() }
                        else { Task { do { try await model.resume() } catch { model.error = error.localizedDescription } } }
                    } label: {
                        ZStack {
                            Circle().fill(Color.black).overlay { Circle().stroke(.red.opacity(0.45), lineWidth: 2) }
                            if model.captureStarting { ProgressView().tint(.red) }
                            else { Image(systemName: model.captureIsRecording ? "pause.fill" : "circle.fill").font(.system(size: 27, weight: .bold)).foregroundStyle(.red).contentTransition(reduceMotion ? .opacity : .symbolEffect(.replace)) }
                        }.frame(width: 68, height: 68)
                    }.buttonStyle(.plain).disabled(model.captureStarting)
                        .accessibilityLabel(model.captureStarting ? "Starting microphone" : model.captureIsRecording ? "Pause recording" : "Resume recording")
                    Spacer(minLength: 2)
                    Color.clear.frame(width: 44, height: 44)
                }
            }.frame(minHeight: 76)
            if let error = recorder.error { Text(error).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            IconAction(symbol: "arrow.up", label: "Send recording", prominent: true) {
                model.pause()
                guard let id = model.activeID else { return }
                guard model.activeDraft?.destination != nil else { sheet = .threads; return }
                guard model.finish() != nil else { return }
                Task { await model.deliver(id) }
            }.disabled(model.captureStarting)
        }
    }
}

/// Bounded redraws come from the recorder's input meter, never an animation timer.
private struct Waveform: View {
    let level: Float
    let recording: Bool
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                for index in 0..<32 {
                    let x = proxy.size.width * CGFloat(index) / 31
                    let amplitude = recording ? CGFloat(max(0.03, level)) : 0.08
                    let height = 3 + amplitude * (index.isMultiple(of: 3) ? 55.0 : 32.0)
                    path.move(to: CGPoint(x: x, y: proxy.size.height / 2 - height / 2))
                    path.addLine(to: CGPoint(x: x, y: proxy.size.height / 2 + height / 2))
                }
            }.stroke(.red.opacity(recording ? 0.9 : 0.35), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }
}
struct QuestionBlock: View {
    @EnvironmentObject var model: AppModel
    let question: BBQuestion
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(question.prompt).privacySensitive().font(.glance).fixedSize(horizontal: false, vertical: true)
            if model.questionsError != nil { Text("Saved question · will check before sending").font(.caption2).foregroundStyle(.secondary) }
            if question.supported {
                ForEach(question.options) { option in
                    GlassButton(title: option.label) { _ = model.choose(question, option: option); haptic(.click) }.privacySensitive().disabled(!model.connected)
                }
            } else { Text("Open BB to answer this question, or record a voice clarification.").font(.footnote).foregroundStyle(.secondary) }
        }
    }
}
struct AnswerUndo: View {
    @EnvironmentObject var model: AppModel
    let answer: PendingAnswer
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(answer.choiceLabel ?? answer.choice).privacySensitive().font(.glance).fixedSize(horizontal: false, vertical: true)
            if answer.status == .waiting {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = max(0, Int(ceil(answer.deadline.timeIntervalSince(context.date))))
                    Text(remaining > 0 ? "Sending in \(remaining)s" : "Waiting to confirm question").font(.caption2).foregroundStyle(.secondary)
                    GlassButton(title: "Undo", symbol: "arrow.uturn.backward") { model.cancel(answer.id) }
                }
            } else {
                Text(answer.error != nil ? "Answer delivery unconfirmed. Check BB before trying again." : "Sending answer").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}
