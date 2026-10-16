import Foundation

@main enum ChatListCheck {
    static func main() throws {
        // External BB JSON keeps the fixture independent of Swift model initializers.
        let data = Data(#"""
        [
          {"id":"old","title":"Root","projectId":"work","updatedAt":10,"environmentBranchName":"release/watch"},
          {"id":"recent","title":"Recent","updatedAt":80},
          {"id":"child","title":"Needle worker","parentThreadId":"old","latestAttentionAt":100},
          {"id":"owned","title":"Owned worker","lifecycleOwnerThreadId":"old","updatedAt":95},
          {"id":"pinB","title":"B","pinnedAt":1,"pinSortKey":"b","updatedAt":1000},
          {"id":"pinA","title":"A","pinnedAt":9,"pinSortKey":"a"},
          {"id":"legacyPin","title":"Legacy","pinnedAt":2},
          {"id":"hidden","title":"Hidden","visibility":"hidden","updatedAt":9999},
          {"id":"archived","title":"Archived","archivedAt":1,"updatedAt":9999},
          {"id":"orphan","titleFallback":"Fallback title","parentThreadId":"missing","updatedAt":20}
        ]
        """#.utf8)
        let threads = try JSONDecoder().decode([BBThread].self, from: data)
        let rows = ChatList.build(threads: threads, projects: [BBProject(id: "work", name: "Satchel")])
        precondition(rows.map(\.id) == ["pinA", "pinB", "legacyPin", "old", "recent", "orphan"], "Pins must retain shared order while children lift root activity")
        precondition(rows.first(where: { $0.id == "old" })?.children.count == 2, "Parent and lifecycle-owner children must fold")
        for query in [" NEEDLE ", "SATCHEL", "release/watch", "Root"] {
            precondition(ChatList.filtered(rows, query: query).map(\.id) == ["old"], "Search must match folded title/project/branch: \(query)")
        }
        precondition(ChatList.filtered(rows, query: "Fallback").map(\.id) == ["orphan"])
        precondition(ChatList.filtered(rows, query: "  ").count == rows.count)
        let cycle = try JSONDecoder().decode([BBThread].self, from: Data(#"[{"id":"a","parentThreadId":"b"},{"id":"b","parentThreadId":"a"}]"#.utf8))
        precondition(ChatList.build(threads: cycle, projects: []).count == 2, "Broken ancestry must terminate")
        print("Chats list projection checks passed")
    }
}
