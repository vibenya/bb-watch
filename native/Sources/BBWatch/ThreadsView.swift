import SwiftUI

/// Right page. Chats by what moved last; a tap makes one the stage.
struct ThreadsView: View {
    @EnvironmentObject var model: AppModel
    @Binding var page: Page
    @State private var search = ""
    @State private var newThread = false
    @State private var recordings = false
    @State private var settings = false
    private var unsent: Int { model.drafts.filter { $0.state != .accepted && ($0.duration > 0 || $0.transcript != nil) }.count }

    var body: some View {
        List {
            Button { newThread = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus").font(.system(size: 14, weight: .black))
                    Text("New thread").font(.system(size: 16, weight: .bold).width(.condensed))
                }.frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            }
            .listItemTint(Mood.working.tint.opacity(0.35))
            ForEach(ChatList.filtered(model.chats, query: search).sorted { $0.activityAt > $1.activityAt }) { chat in
                Button {
                    model.currentThreadID = chat.id; model.newThreadProject = nil
                    haptic(.click)
                    withAnimation(.snappy) { page = .stage }
                } label: { ThreadRow(chat: chat, current: chat.id == model.currentThreadID) }
            }
            if model.chats.isEmpty {
                Text(model.connected ? (model.refreshing ? "Loading chats" : "No chats yet") : "Connect BB in Settings").foregroundStyle(.secondary)
            }
            Section {
                if unsent > 0 {
                    Button { recordings = true } label: { Label("Recordings · \(unsent)", systemImage: "waveform") }
                }
                Button { settings = true } label: { Label(model.connected ? "Settings" : "Connect BB", systemImage: model.connected ? "gearshape" : "link") }
            }
        }
        .searchable(text: $search)
        .containerBackground(.black.gradient, for: .navigation)
        .sheet(isPresented: $newThread) { ProjectPicker(page: $page) }
        .sheet(isPresented: $recordings) { RecordingsSheet() }
        .sheet(isPresented: $settings) { SettingsSheet() }
    }
}

struct ThreadRow: View {
    let chat: ChatList.Row
    var current = false
    private var mood: Mood {
        if chat.thread.hasPendingInteraction == true { return .needsYou }
        switch chat.thread.status { case "active": return .working; case "error": return .error; default: return .idle }
    }
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(mood == .idle ? Color.white.opacity(0.18) : mood.tint).frame(width: 7, height: 7).padding(.top, 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(chat.thread.displayTitle)
                    .font(.system(size: 15, weight: current ? .bold : .semibold)).lineLimit(2)
                HStack(spacing: 4) {
                    if chat.isPinned { Image(systemName: "pin.fill").font(.system(size: 9)) }
                    Text([chat.projectName, relativeLabel(chat.activityAt)].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.kicker).lineLimit(1)
                }.foregroundStyle(.secondary)
            }
        }.padding(.vertical, 2)
    }
}

/// Pick a project for a new thread, then go straight to the microphone.
struct ProjectPicker: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Binding var page: Page
    var body: some View {
        List {
            Section("New thread in") {
                ForEach(model.projects) { project in
                    Button(project.name) {
                        model.newThreadProject = project; dismiss()
                        withAnimation(.snappy) { page = .record }
                    }.font(.system(size: 15, weight: .semibold))
                }
            }
        }.containerBackground(.black.gradient, for: .navigation)
    }
}
