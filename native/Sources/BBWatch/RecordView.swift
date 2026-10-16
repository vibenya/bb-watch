import SwiftUI

/// Left page. Voice Memos discipline: one red control, a big clock, nothing else to decide.
/// Tap the circle to start; tap it again to send. Pause stays a small secondary action.
struct RecordView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var recorder: WatchRecorder
    @Binding var page: Page
    @State private var pickTarget = false
    @State private var picker = false

    private var active: Bool { model.activeID != nil }
    private var mood: Mood { recorder.isRecording ? .recording : (active ? .idle : .idle) }
    private var targetLabel: String {
        if let project = model.newThreadProject { return "New · \(project.name)" }
        if let thread = model.currentThread { return thread.displayTitle }
        return "Choose where to send"
    }

    var body: some View {
        ZStack {
            Stage(mood: mood)
            VStack(spacing: 0) {
                Button { picker = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: model.newThreadProject == nil ? "arrow.turn.down.right" : "plus").font(.system(size: 10, weight: .bold))
                        Kicker(text: targetLabel)
                    }
                }.buttonStyle(.plain).disabled(active)
                Spacer(minLength: 0)
                Text(durationLabel(recorder.elapsed))
                    .font(.poster(46).monospacedDigit())
                    .foregroundStyle(recorder.isRecording ? .white : .white.opacity(active ? 0.9 : 0.35))
                    .contentTransition(.numericText())
                    .animation(.linear(duration: 0.2), value: recorder.elapsed)
                Text(recorder.isRecording ? "RECORDING" : active ? "PAUSED" : "TAP TO RECORD")
                    .font(.kicker).tracking(1.2).foregroundStyle(recorder.isRecording ? Mood.recording.tint : .secondary)
                    .contentTransition(.interpolate)
                Spacer(minLength: 0)
                HStack(spacing: 12) {
                    if active {
                        SmallGlass(symbol: recorder.isRecording ? "pause.fill" : "mic.fill") { toggle() }
                    }
                    RecordButton(recording: recorder.isRecording, active: active, level: recorder.level) { primary() }
                    if active {
                        SmallGlass(symbol: "tray.and.arrow.down") { save() }
                    }
                }
                .animation(.snappy, value: active)
                if let error = recorder.error ?? (active ? nil : nil) {
                    Text(error).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            .padding(.horizontal, 10).padding(.top, 10).padding(.bottom, 12)
        }
        .sheet(isPresented: $picker) { TargetPicker() }
    }

    private func primary() {
        if active { send() } else {
            haptic(.click)
            Task { await model.start(destination: model.recordTarget) }
        }
    }
    private func toggle() {
        if recorder.isRecording { model.pause() }
        else { Task { do { try await model.resume() } catch { model.error = error.localizedDescription } } }
    }
    private func send() {
        guard let id = model.finish() else { return }
        guard let target = model.draft(id)?.destination ?? model.recordTarget else { picker = true; return }
        haptic(.success)
        withAnimation(.snappy) { page = .stage }
        Task { await model.deliver(id, destination: target) }
    }
    /// Keep the audio on the watch without sending; it stays in Recordings.
    private func save() {
        _ = model.finish(); haptic(.stop)
    }
}

/// The hero control. Idle: a red disc with a mic. Recording: a white disc with an arrow,
/// wrapped in a volt ring that breathes with the input level.
private struct RecordButton: View {
    var recording: Bool
    var active: Bool
    var level: Float
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().stroke(Mood.recording.tint.opacity(recording ? 0.9 : 0), lineWidth: 3)
                    .scaleEffect(1 + CGFloat(level) * 0.45)
                    .opacity(Double(1 - level * 0.6))
                    .animation(.easeOut(duration: 0.12), value: level)
                Circle().fill(active ? Color.white : Mood.recording.tint)
                    .frame(width: 66, height: 66)
                    .shadow(color: (active ? Color.white : Mood.recording.tint).opacity(0.5), radius: recording ? 14 : 6)
                Image(systemName: active ? "arrow.up" : "mic.fill")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(active ? .black : .white)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 84, height: 84)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(active ? "Send" : "Record")
    }
}

private struct SmallGlass: View {
    var symbol: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 15, weight: .bold)).frame(width: 38, height: 38)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .transition(.scale.combined(with: .opacity))
    }
}

/// Where the next recording goes: reply to a chat, or start a new thread in a project.
struct TargetPicker: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    var body: some View {
        List {
            Section("New thread") {
                ForEach(model.projects) { project in
                    Button {
                        model.newThreadProject = project; dismiss()
                    } label: { Label(project.name, systemImage: "plus").font(.system(size: 15, weight: .semibold)) }
                }
            }
            Section("Reply to") {
                ForEach(ChatList.filtered(model.chats, query: search).sorted { $0.activityAt > $1.activityAt }) { chat in
                    Button {
                        model.currentThreadID = chat.id; model.newThreadProject = nil; dismiss()
                    } label: { ThreadRow(chat: chat, current: chat.id == model.currentThreadID) }
                }
            }
        }
        .searchable(text: $search)
        .containerBackground(.black.gradient, for: .navigation)
    }
}
