import SwiftUI

struct ThreadsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    var body: some View {
        List {
            Button { model.selectNew(); dismiss() } label: { Label("New", systemImage: "plus.circle").frame(minHeight: 44) }
                .listItemTint(GlanceStyle.surface)
            ForEach(ChatList.filtered(model.chats, query: search).sorted { $0.activityAt > $1.activityAt }) { chat in
                Button { model.selectThread(chat.id); dismiss() } label: {
                    ThreadRow(chat: chat, current: model.contextDestination == .thread(id: chat.id))
                }
                ForEach(chat.children.sorted { ($0.updatedAt ?? 0) > ($1.updatedAt ?? 0) }) { child in
                    Button { model.selectThread(child.id); dismiss() } label: {
                        HStack {
                            Image(systemName: "arrow.turn.down.right").foregroundStyle(.secondary)
                            Text(child.displayTitle).font(.glance).fixedSize(horizontal: false, vertical: true)
                            if model.contextDestination == .thread(id: child.id) { Image(systemName: "checkmark").foregroundStyle(GlanceStyle.lime) }
                        }.frame(minHeight: 44)
                    }
                }
            }
            if model.chats.isEmpty { Text(model.connected ? "No chats yet" : "Connect BB in Settings").foregroundStyle(.secondary) }
        }.searchable(text: $search).containerBackground(.black, for: .navigation)
    }
}
struct ThreadRow: View {
    let chat: ChatList.Row
    var current = false
    private var symbol: String {
        if chat.thread.hasPendingInteraction == true { return "questionmark.circle" }
        switch chat.thread.status {
        case "active", "starting", "pending": return "circle.dotted"
        case "error": return "exclamationmark.circle"
        default: return "text.bubble"
        }
    }
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).foregroundStyle(GlanceStyle.lime).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(chat.thread.displayTitle).font(.glance).lineLimit(2)
                HStack(spacing: 3) {
                    if chat.isPinned { Image(systemName: "pin.fill").accessibilityLabel("Pinned") }
                    Text([chat.projectName, relativeLabel(chat.activityAt)].filter { !$0.isEmpty }.joined(separator: " · "))
                }.font(.caption2).foregroundStyle(.secondary)
            }
            if current { Image(systemName: "checkmark").foregroundStyle(GlanceStyle.lime).accessibilityLabel("Selected") }
        }.frame(minHeight: 44)
    }
}
struct ProjectPicker: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            ForEach(model.projects) { project in
                Button { model.selectProject(project); dismiss() } label: {
                    HStack {
                        Text(project.name).font(.glance).fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        if model.contextProject?.id == project.id { Image(systemName: "checkmark").foregroundStyle(GlanceStyle.lime) }
                    }.frame(minHeight: 44)
                }
            }
            if model.projects.isEmpty { Text(model.connected ? "Projects are unavailable. Try refreshing your connection." : "Connect BB to load projects. You can record now and choose later.").font(.footnote) }
        }.containerBackground(.black, for: .navigation)
    }
}
struct ModelPicker: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var providers: [BBProvider] = []
    @State private var models: [BBModel] = []
    @State private var providerID: String?
    @State private var loadedProviderID: String?
    @State private var loading = false
    @State private var failure: String?
    @State private var projectDefault: String?
    @State private var revision = UUID()
    var body: some View {
        List {
            Button {
                model.selectModel(providerID: nil, modelID: nil, name: nil); dismiss()
            } label: {
                VStack(alignment: .leading) {
                    Text("Project default").font(.glance)
                    if let projectDefault { Text(projectDefault).font(.caption2).foregroundStyle(.secondary) }
                }.frame(minHeight: 44)
            }
            if loading { ProgressView("Loading models") }
            if let failure { Text(failure).font(.footnote).foregroundStyle(.secondary) }
            if providers.count > 1 {
                Picker("Provider", selection: $providerID) {
                    ForEach(providers.filter(\.available)) { provider in Text(provider.displayName).tag(Optional(provider.id)) }
                }
            }
            ForEach(models) { choice in
                Button {
                    guard !loading, let providerID, loadedProviderID == providerID else { return }
                    model.selectModel(providerID: providerID, modelID: choice.model, name: choice.displayName); dismiss()
                } label: { Text(choice.displayName).font(.glance).frame(minHeight: 44) }
                .disabled(loading || loadedProviderID != providerID)
            }
            if !loading && failure != nil { Button("Retry") { Task { await load(initial: true) } } }
        }
        .containerBackground(.black, for: .navigation)
        .task { await load(initial: true) }
        .onChange(of: providerID) { old, new in
            if old != nil, new != old { Task { await load(initial: false) } }
        }
    }
    private func load(initial: Bool) async {
        guard !model.isFixture else { failure = "Local fixture · project default only"; return }
        guard model.connected else { failure = "Connect BB to load models. Project default will be applied by BB."; return }
        let token = UUID(); revision = token; loading = true; failure = nil; models = []
        let identity = model.identity
        do {
            var requested = providerID
            if initial, let project = model.contextProject {
                let defaults = try await model.client.projectExecutionDefaults(projectID: project.id)
                if let draft = model.activeDraft { requested = draft.providerID ?? defaults?.providerId }
                else { requested = model.selectedProviderID ?? defaults?.providerId }
                projectDefault = defaults?.model
            }
            let options = try await model.client.executionOptions(providerID: requested)
            guard revision == token, identity == model.identity, !Task.isCancelled else { return }
            providers = options.providers
            providerID = requested ?? options.providers.first?.id
            loadedProviderID = requested ?? options.providers.first?.id
            models = options.models
            failure = options.modelLoadError == nil ? nil : "Models could not be loaded. Project default remains available."
            if models.isEmpty && failure == nil { failure = "No models available. BB can apply the project default." }
        } catch {
            guard revision == token, !Task.isCancelled else { return }
            failure = "Models unavailable. Project default remains available."
        }
        if revision == token { loading = false }
    }
}
