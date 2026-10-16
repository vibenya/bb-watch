import Foundation

/// Native projection of the installed Chats plugin's active, folded list.
enum ChatList {
    struct Row: Identifiable, Sendable {
        let thread: BBThread
        let children: [BBThread]
        let projectName: String
        let activityAt: Double
        let searchText: String
        var id: String { thread.id }
        var isPinned: Bool { thread.pinnedAt != nil }
    }

    static func build(threads: [BBThread], projects: [BBProject]) -> [Row] {
        var seen = Set<String>()
        let visible = threads.filter {
            $0.visibility != "hidden" && $0.archivedAt == nil && seen.insert($0.id).inserted
        }
        let byID = Dictionary(uniqueKeysWithValues: visible.map { ($0.id, $0) })
        let projectNames = projects.reduce(into: [String: String]()) { $0[$1.id] = $1.name }
        var families: [String: (BBThread, [BBThread], Double)] = [:]
        var insertionOrder: [String] = []
        for thread in visible {
            var root = thread
            var visited: Set<String> = [root.id]
            while let parentID = root.parentThreadId ?? root.lifecycleOwnerThreadId,
                  let parent = byID[parentID], visited.insert(parent.id).inserted {
                root = parent
            }
            if families[root.id] == nil {
                insertionOrder.append(root.id)
                families[root.id] = (root, [], 0)
            }
            if thread.id != root.id { families[root.id]!.1.append(thread) }
            families[root.id]!.2 = max(families[root.id]!.2, thread.updatedAt ?? 0, thread.latestAttentionAt ?? 0)
        }
        let rows = insertionOrder.compactMap { id -> Row? in
            guard let (thread, children, activity) = families[id] else { return nil }
            let projectName = projectNames[thread.projectId ?? ""] ?? ""
            let titles = children.map { $0.title ?? $0.titleFallback ?? "" }
            let search = ([thread.title ?? thread.titleFallback ?? "", projectName, thread.environmentBranchName ?? ""] + titles)
                .joined(separator: "\n").lowercased(with: .current)
            return Row(thread: thread, children: children, projectName: projectName, activityAt: activity, searchText: search)
        }
        // Preserve incoming order for exact ties, matching the plugin's stable sort.
        return rows.enumerated().sorted { left, right in
            let a = left.element, b = right.element
            if a.isPinned != b.isPinned { return a.isPinned }
            if a.isPinned {
                switch (a.thread.pinSortKey, b.thread.pinSortKey) {
                case let (aKey?, bKey?) where aKey != bKey: return aKey < bKey
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil):
                    if a.thread.pinnedAt != b.thread.pinnedAt { return (a.thread.pinnedAt ?? 0) < (b.thread.pinnedAt ?? 0) }
                default: break
                }
            } else if a.activityAt != b.activityAt { return a.activityAt > b.activityAt }
            return left.offset < right.offset
        }.map(\.element)
    }

    static func filtered(_ rows: [Row], query: String) -> [Row] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(with: .current)
        return needle.isEmpty ? rows : rows.filter { $0.searchText.contains(needle) }
    }
}
