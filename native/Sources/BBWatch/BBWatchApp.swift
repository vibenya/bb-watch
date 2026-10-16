import SwiftUI

@main
struct BBWatchApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            HomeView().environmentObject(model)
                .alert("BB", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                    Button("OK", role: .cancel) { model.error = nil }
                } message: { Text(model.error ?? "") }
                .onChange(of: phase) { _, next in
                    if next == .active { Task { await model.refresh() } }
                }
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @State private var showRecording = false
    private var unsentCount: Int { model.drafts.filter { $0.state != .accepted }.count }
    var body: some View {
        NavigationStack {
            List {
                Button {
                    Task { await model.start(); showRecording = model.activeID != nil }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: model.activeID == nil ? "mic.circle.fill" : "waveform.circle.fill")
                            .font(.system(size: 35)).symbolRenderingMode(.hierarchical)
                        Text(model.activeID == nil ? "Record" : "Resume recording").font(.headline)
                    }.frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                }.listItemTint(.accentColor)
                NavigationLink { QuestionsView() } label: {
                    HomeRow(title: "Needs You", symbol: "questionmark.bubble.fill", color: .orange, count: model.questions.count)
                }
                NavigationLink { ThreadsView() } label: {
                    HomeRow(title: "Chats", symbol: "bubble.left.and.bubble.right.fill", color: .cyan)
                }
                NavigationLink { DraftsView() } label: {
                    HomeRow(title: "Recordings", symbol: "waveform", color: .purple, count: unsentCount)
                }
                NavigationLink { SettingsView() } label: {
                    HomeRow(title: model.connected ? "Settings" : "Connect BB", symbol: model.connected ? "gearshape.fill" : "link", color: .secondary)
                }
                if model.refreshing { ProgressView("Refreshing") }
                if let error = model.syncError {
                    Text(error).font(.footnote).foregroundStyle(.secondary)
                    Button("Retry") { Task { await model.refresh() } }
                }
                if let sync = model.lastSync { Text("Updated \(sync.formatted(date: .omitted, time: .shortened))").font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image("BBLogo").renderingMode(.template).resizable().scaledToFit()
                        .foregroundStyle(.white).frame(width: 32, height: 26).accessibilityLabel("BB")
                }
            }
            .navigationDestination(isPresented: $showRecording) { RecordingView() }
            .task { await model.refresh() }
        }
    }
}

private struct HomeRow: View {
    let title: String
    let symbol: String
    let color: Color
    var count: Int = 0
    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol).symbolRenderingMode(.hierarchical)
                .foregroundStyle(color).font(.title3).frame(width: 26)
            Text(title).frame(maxWidth: .infinity, alignment: .leading)
            if count > 0 { Text(count.formatted()).font(.callout.monospacedDigit().weight(.semibold)).foregroundStyle(color) }
        }.frame(minHeight: 40)
    }
}

struct RecordingView: View {
    @EnvironmentObject var model: AppModel
    @State private var resultID: UUID?
    @State private var sending = false
    var body: some View {
        RecordingContent(recorder: model.recorder, send: {
            if let id = model.finish() { resultID = id; sending = true }
        }, save: {
            if let id = model.finish() { resultID = id; sending = false }
        }, toggle: {
            if model.recorder.isRecording { model.pause() }
            else { Task { do { try await model.resume() } catch { model.error = error.localizedDescription } } }
        }, context: model.activeID.flatMap(model.draft).flatMap { draft in
            guard case .thread(let threadID) = draft.destination else { return nil }
            return model.threads.first(where: { $0.id == threadID })?.title ?? "Reply"
        } ?? "")
        .navigationDestination(isPresented: Binding(get: { resultID != nil }, set: { if !$0 { resultID = nil } })) {
            if let id = resultID { DraftView(id: id, sendOnOpen: sending) }
        }
    }
}
struct RecordingContent: View {
    @ObservedObject var recorder: WatchRecorder
    var send: () -> Void
    var save: () -> Void
    var toggle: () -> Void
    var context: String
    var body: some View {
        ScrollView {
            VStack(spacing: 9) {
                if !context.isEmpty { Text(context).font(.caption).foregroundStyle(.secondary) }
                Text(durationLabel(recorder.elapsed)).font(.system(.largeTitle, design: .rounded).monospacedDigit())
                Text(recorder.isRecording ? "Saving on watch" : "Paused").font(.footnote).foregroundStyle(.secondary)
                Button(action: send) { Label("Send", systemImage: "arrow.up").frame(maxWidth: .infinity, minHeight: 44) }
                    .buttonStyle(.borderedProminent).disabled(recorder.finalizationFailed)
                HStack {
                    Button(recorder.isRecording ? "Pause" : "Resume", action: toggle)
                    Button("Save", action: save)
                }.buttonStyle(.bordered)
                if let error = recorder.error { Text(error).font(.footnote) }
            }.padding(.horizontal, 6)
        }.navigationTitle(recorder.isRecording ? "Recording" : "Paused")
    }
}

struct DraftsView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        List {
            if model.drafts.isEmpty { Text("No recordings") }
            ForEach(model.drafts.reversed()) { draft in
                NavigationLink { DraftView(id: draft.id) } label: {
                    VStack(alignment: .leading) {
                        Text(draft.createdAt, style: .date)
                        Text("\(durationLabel(draft.duration)) · \(statusLabel(draft.state))").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }.navigationTitle("Recordings")
    }
}
struct DraftView: View {
    @EnvironmentObject var model: AppModel
    let id: UUID
    var sendOnOpen = false
    @State private var recipients = false
    @State private var recording = false
    @State private var deleting = false
    @State private var text = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            if let value = model.draft(id) {
                Text(durationLabel(value.duration)).font(.title2.monospacedDigit())
                Text(statusLabel(value.state))
                if value.recoveryIssue != nil {
                    Text("Audio was found after an interruption. Review recovered parts before sending.").font(.footnote)
                    Button("Review and recover") { model.recover(id) }
                }
                if let error = value.error { Text(error).font(.footnote) }
                PlaybackControls(player: model.playback, sourceID: id.uuidString, play: {
                    do { if let store = model.store { model.playback.play(chunks: value.chunks, directory: try store.chunksDirectory(for: id)) } }
                    catch { model.error = error.localizedDescription }
                })
                if value.state == .queued && !model.sending.contains(id) {
                    Button("Cancel queued send") { model.cancelQueue(id) }
                }
                if value.state == .draft || value.state == .failed {
                    Button("Send", systemImage: "arrow.up") { send() }.listItemTint(.accentColor)
                    Button("Continue recording", systemImage: "mic") {
                        Task { await model.start(existing: id); recording = model.activeID != nil }
                    }
                    TextField("Edit transcript", text: $text)
                    Button("Save transcript") {
                        var edited = value; edited.transcript = text
                        do { try model.save(edited) } catch { model.error = error.localizedDescription }
                    }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if let transcript = value.transcript { Text(transcript) }
                if let previous = value.previousTranscript {
                    Section("Previous transcript") { Text(previous) }
                }
                if value.state == .checkingDelivery {
                    Text("Delivery is unconfirmed. Check the thread before retrying to avoid a duplicate.").font(.footnote)
                }
                if case .thread(let threadID) = value.destination {
                    NavigationLink("Open thread") { ThreadView(threadID: threadID) }
                }
                if !model.sending.contains(id) && value.state != .checkingDelivery {
                    Button("Delete", role: .destructive) { deleting = true }
                }
            } else { Text("Recording unavailable") }
        }
        .navigationTitle("Recording")
        .navigationDestination(isPresented: $recipients) { RecipientView(id: id) }
        .navigationDestination(isPresented: $recording) { RecordingView() }
        .confirmationDialog("Delete recording from this watch?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete recording", role: .destructive) {
                do { try model.store?.deleteDraft(id: id); model.reload(); dismiss() } catch { model.error = error.localizedDescription }
            }
        }
        .task { text = model.draft(id)?.transcript ?? ""; if sendOnOpen { send() } }
    }
    private func send() {
        guard model.connected else { model.error = ConnectionError.notConnected.localizedDescription; return }
        if model.draft(id)?.destination == nil { recipients = true }
        else { Task { await model.deliver(id) } }
    }
}
struct RecipientView: View {
    @EnvironmentObject var model: AppModel
    let id: UUID
    @State private var delivered = false
    @State private var search = ""
    var body: some View {
        List {
            Text("Choose where to send this recording.").font(.footnote)
            NavigationLink("New thread") {
                List(model.projects) { project in
                    Button(project.name) { submit(.project(id: project.id)) }
                }.navigationTitle("Project")
            }
            ForEach(ChatList.filtered(model.chats, query: search)) { chat in
                if chat.children.isEmpty {
                    Button { submit(.thread(id: chat.id)) } label: { ChatRow(chat: chat) }
                } else {
                    NavigationLink {
                        List([chat.thread] + chat.children) { thread in
                            Button(thread.title ?? thread.titleFallback ?? "Untitled chat") {
                                submit(.thread(id: thread.id))
                            }
                        }.navigationTitle("Send to")
                    } label: { ChatRow(chat: chat) }
                }
            }
            if model.chats.isEmpty { Text("No chats available") }
            Button("Refresh") { Task { await model.refresh() } }
        }.navigationTitle("Send to").searchable(text: $search)
        .navigationDestination(isPresented: $delivered) { DraftView(id: id) }
    }
    private func submit(_ destination: RecordingDestination) {
        delivered = true
        Task { await model.deliver(id, destination: destination) }
    }
}
struct ThreadsView: View {
    @EnvironmentObject var model: AppModel
    @State private var search = ""
    var body: some View {
        List {
            ForEach(ChatList.filtered(model.chats, query: search)) { chat in
                NavigationLink { ThreadView(threadID: chat.id) } label: { ChatRow(chat: chat) }
            }
            if model.chats.isEmpty { Text(model.refreshing ? "Loading chats" : "No chats available") }
            if let error = model.syncError { Text(error).font(.footnote).foregroundStyle(.secondary) }
            Button("Refresh") { Task { await model.refresh() } }
        }.navigationTitle("Chats").searchable(text: $search)
    }
}
private struct ChatRow: View {
    let chat: ChatList.Row
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                if chat.isPinned { Image(systemName: "pin.fill").font(.caption).foregroundStyle(.orange).accessibilityLabel("Pinned") }
                Text(chat.thread.title ?? chat.thread.titleFallback ?? "Untitled chat").lineLimit(3)
            }
            if !chat.projectName.isEmpty { Text(chat.projectName).font(.caption2).foregroundStyle(.secondary) }
        }
    }
}

struct ThreadView: View {
    @EnvironmentObject var model: AppModel
    let threadID: String
    @State private var messages: [BBMessage] = []
    @State private var error: String?
    @State private var recording = false
    @State private var loading = false
    var body: some View {
        List {
            Button("Record reply", systemImage: "mic.fill") { Task { await model.start(destination: .thread(id: threadID)); recording = model.activeID != nil } }.listItemTint(.accentColor)
            if let chat = model.chats.first(where: { $0.id == threadID }), !chat.children.isEmpty {
                NavigationLink("Related chats (\(chat.children.count))") {
                    List(chat.children) { child in
                        NavigationLink(child.title ?? child.titleFallback ?? "Untitled chat") { ThreadView(threadID: child.id) }
                    }.navigationTitle("Related chats")
                }
            }
            if loading { ProgressView() }
            if let error { Text(error).font(.footnote) }
            ForEach(messages) { message in
                if message.role == "assistant" {
                    NavigationLink { ReplyView(message: message, threadID: threadID) } label: {
                        VStack(alignment: .leading) { Text("Agent").font(.caption).foregroundStyle(.secondary); Text(message.text).lineLimit(6) }
                    }
                } else { Text(message.text).foregroundStyle(.secondary) }
            }
            Button("Refresh") { Task { await load() } }
        }.navigationTitle(model.threads.first { $0.id == threadID }?.title ?? "Thread")
        .navigationDestination(isPresented: $recording) { RecordingView() }
        .task { messages = model.cachedMessages(threadID: threadID); await load() }
    }
    private func load() async {
        guard model.connected, !loading else { return }
        loading = true; defer { loading = false }
        do { messages = try await model.loadMessages(threadID: threadID); error = nil }
        catch is CancellationError { }
        catch let failure as URLError where failure.code == .cancelled { }
        catch { self.error = error.localizedDescription }
    }
}
struct ReplyView: View {
    @EnvironmentObject var model: AppModel
    let message: BBMessage
    let threadID: String
    @State private var recording = false
    var body: some View {
        List {
            Text("Full response").font(.caption).foregroundStyle(.secondary)
            PlaybackControls(player: model.playback, sourceID: message.text, play: { model.playback.speak(message.text) })
            Text(message.text)
            Button("Record reply", systemImage: "mic") { Task { await model.start(destination: .thread(id: threadID)); recording = model.activeID != nil } }
        }.navigationTitle("Agent response")
        .navigationDestination(isPresented: $recording) { RecordingView() }
    }
}
struct PlaybackControls: View {
    @ObservedObject var player: WatchPlayback
    var sourceID: String
    var play: () -> Void
    var active: Bool { player.sourceID == sourceID }
    var body: some View {
        Button(active && player.isPlaying ? "Pause" : "Listen", systemImage: active && player.isPlaying ? "pause.fill" : "play.fill") {
            if active && player.isPlaying { player.pause() } else if active && player.isPaused { player.resume() } else { play() }
        }
        if let error = player.error { Text(error).font(.footnote) }
    }
}
struct QuestionsView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        List {
            ForEach(model.pending.filter { $0.status != .accepted }) { answer in
                NavigationLink("Sending answer") { AnswerReceiptView(id: answer.id) }
            }
            ForEach(model.questions.filter { question in !model.pending.contains(where: { $0.interactionID == question.id && $0.threadID == question.threadID }) }) { question in
                NavigationLink(question.title) { QuestionView(question: question) }
            }
            if let error = model.questionsError { Text("Could not refresh questions. \(error)").font(.footnote) }
            if model.questionsError == nil && model.questions.isEmpty && !model.pending.contains(where: { $0.status != .accepted }) { Text(model.lastSync == nil ? "No questions loaded" : "No pending questions") }
            Button("Refresh") { Task { await model.refresh() } }
        }.navigationTitle("Needs You")
    }
}
struct QuestionView: View {
    @EnvironmentObject var model: AppModel
    let question: BBQuestion
    @State private var receipt: UUID?
    private var pendingAnswer: PendingAnswer? { model.pending.first { $0.threadID == question.threadID && $0.interactionID == question.id } }
    @State private var recording = false
    var body: some View {
        List {
            Text(question.prompt)
            if let pendingAnswer {
                NavigationLink("View response") { AnswerReceiptView(id: pendingAnswer.id) }
            } else if question.supported {
                ForEach(question.options) { option in
                    Button {
                        receipt = model.choose(question, option: option)
                    } label: {
                        Text(option.label).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else { Text("This question type isn't supported here. You can record a thread clarification.").font(.footnote) }
            if pendingAnswer == nil {
            Button("Record voice reply", systemImage: "mic") {
                Task { await model.start(destination: .thread(id: question.threadID)); recording = model.activeID != nil }
            }
            Text("Voice replies are sent as thread clarifications. They don't approve actions.").font(.footnote).foregroundStyle(.secondary)
            }
        }.navigationTitle("Question")
        .navigationDestination(isPresented: Binding(get: { receipt != nil }, set: { if !$0 { receipt = nil } })) {
            if let receipt { AnswerReceiptView(id: receipt) }
        }
        .navigationDestination(isPresented: $recording) { RecordingView() }
    }
}
struct AnswerReceiptView: View {
    @EnvironmentObject var model: AppModel
    @State private var recording = false
    let id: UUID
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 5) {
            if let answer = model.pending.first(where: { $0.id == id }) {
                if answer.status == .waiting {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = max(0, Int(ceil(answer.deadline.timeIntervalSince(context.date))))
                        Button(remaining > 0 ? "Cancel · \(remaining)s" : "Cancel send") { model.cancel(id); dismiss() }
                            .buttonStyle(.bordered).frame(minHeight: 44)
                    }
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(answer.status == .accepted ? "Answer accepted" : answer.status == .committing ? "Checking delivery" : "Sending answer")
                        Text(answer.choiceLabel ?? model.questions.first(where: { $0.id == answer.interactionID && $0.threadID == answer.threadID })?.options.first(where: { $0.id == answer.choice })?.label ?? answer.choice)
                        if let error = answer.error { Text(error).font(.footnote) }
                        if answer.status == .accepted {
                            NavigationLink("Open thread") { ThreadView(threadID: answer.threadID) }
                            Button("Record follow-up", systemImage: "mic") {
                                Task { await model.start(destination: .thread(id: answer.threadID)); recording = model.activeID != nil }
                            }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            } else { Text("Answer cancelled or question resolved") }
        }.navigationTitle("Answer")
        .navigationDestination(isPresented: $recording) { RecordingView() }
    }
}
struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var code = ""
    @State private var pairing = false
    var body: some View {
        List {
            if model.connected {
                Label("BB connected", systemImage: "checkmark.circle")
                Text(URL(string: model.connection.serverURL)?.host ?? "").font(.footnote)
            }
            Text("In BB, open Settings → Mobile → Add mobile device, then enter the one-time code here.").font(.footnote)
            TextField("Pairing code", text: $code)
            Button(pairing ? "Connecting…" : "Connect BB") {
                pairing = true
                Task { await model.pair(code: code); code = ""; pairing = false }
            }.disabled(code.isEmpty || pairing || model.recorder.isRecording || !model.sending.isEmpty)
            Text("Recordings stay on this watch until you delete them. Tap Listen to play a reply.").font(.footnote).foregroundStyle(.secondary)
        }.navigationTitle("Settings")
    }
}
func durationLabel(_ value: TimeInterval) -> String {
    let seconds = max(0, Int(value))
    return seconds >= 3600 ? String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60) : String(format: "%02d:%02d", seconds / 60, seconds % 60)
}
func statusLabel(_ value: RecordingState) -> String {
    switch value {
    case .draft: return "Saved on watch"
    case .queued: return "Queued"
    case .transcribing: return "Transcribing"
    case .checkingDelivery: return "Checking delivery"
    case .accepted: return "Accepted by BB"
    case .failed: return "Saved · send failed"
    }
}
