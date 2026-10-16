import XCTest
@testable import BBWatchCore

final class DurableStoreTests: XCTestCase {
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func testReopenRetainsQueueDestinationTranscriptAndOriginalUntilExplicitDeletion() throws {
        let root = try temporaryDirectory()
        let store = try DurableStore(directory: root)
        let draft = RecordingDraft(duration: 31, state: .queued, destination: .thread(id: "thread-1"), chunks: [AudioChunk(filename: "0001.caf", duration: 31)], serverIdentity: "https://bb.example/account-1", transcript: "Send this complete sentence")
        let audio = try store.chunksDirectory(for: draft.id).appendingPathComponent("0001.caf")
        try Data([1, 2, 3]).write(to: audio)
        try store.saveDraft(draft)
        let reopened = try DurableStore(directory: root)
        XCTAssertEqual(try reopened.loadDrafts(), [draft])
        var failed = draft
        failed.state = .failed; failed.error = "Offline"
        try reopened.saveDraft(failed)
        XCTAssertEqual(try Data(contentsOf: audio), Data([1, 2, 3]))
        try reopened.deleteDraft(id: draft.id)
        XCTAssertTrue(try reopened.loadDrafts().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: audio.path))
    }

    func testCorruptionPreservesBytesAndDoesNotHideOtherDraftsOrOrphanAudio() throws {
        let root = try temporaryDirectory()
        let store = try DurableStore(directory: root)
        let valid = RecordingDraft()
        try store.saveDraft(valid)
        let damagedID = UUID()
        let audio = try store.chunksDirectory(for: damagedID).appendingPathComponent("0001.caf")
        try Data([42]).write(to: audio)
        let metadata = audio.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("metadata.json")
        let corrupt = Data("{broken".utf8)
        try corrupt.write(to: metadata)
        let orphanID = UUID()
        let orphan = try store.chunksDirectory(for: orphanID).appendingPathComponent("0002.caf")
        try Data([99]).write(to: orphan)
        let reopened = try DurableStore(directory: root)
        let recovered = try reopened.loadDrafts()
        XCTAssertEqual(Set(recovered.map(\.id)), Set([valid.id, damagedID, orphanID]))
        XCTAssertEqual(recovered.first { $0.id == damagedID }?.chunks.map(\.filename), ["0001.caf"])
        XCTAssertEqual(recovered.first { $0.id == orphanID }?.chunks.map(\.filename), ["0002.caf"])
        XCTAssertFalse(reopened.recoveryWarnings.isEmpty)
        XCTAssertThrowsError(try reopened.saveDraft(try XCTUnwrap(recovered.first { $0.id == damagedID })))
        XCTAssertEqual(try Data(contentsOf: metadata), corrupt)
        XCTAssertEqual(try Data(contentsOf: audio), Data([42]))
    }

    func testDeadlineSurvivesReopenAndCommitCannotBeCancelledOrBlindlyRetried() throws {
        let root = try temporaryDirectory()
        let store = try DurableStore(directory: root)
        let deadline = Date(timeIntervalSince1970: 1_000)
        let answer = PendingAnswer(threadID: "t", interactionID: "i", choice: "option-a", deadline: deadline, choiceLabel: "Do not publish until reviewed")
        try store.savePendingAnswer(answer)
        let reopened = try DurableStore(directory: root)
        XCTAssertEqual(try reopened.loadPendingAnswers(), [answer])
        var relabeled = answer
        relabeled.choiceLabel = "Publish immediately"
        XCTAssertThrowsError(try reopened.savePendingAnswer(relabeled))
        XCTAssertEqual(try reopened.loadPendingAnswers().first?.choiceLabel, "Do not publish until reviewed")
        XCTAssertThrowsError(try reopened.beginCommit(id: answer.id, now: deadline.addingTimeInterval(-1)))
        let committed = try reopened.beginCommit(id: answer.id, now: deadline)
        XCTAssertEqual(committed.status, .committing)
        let afterCrash = try DurableStore(directory: root)
        XCTAssertEqual(try afterCrash.loadPendingAnswers().first?.status, .committing)
        XCTAssertFalse(try afterCrash.cancelPendingAnswer(id: answer.id))
        XCTAssertThrowsError(try afterCrash.beginCommit(id: answer.id, now: deadline.addingTimeInterval(100)))
        XCTAssertThrowsError(try afterCrash.savePendingAnswer(answer))
        var accepted = committed
        accepted.status = .accepted
        XCTAssertThrowsError(try afterCrash.savePendingAnswer(accepted))
        accepted.messageId = "receipt-1"
        try afterCrash.savePendingAnswer(accepted)
        XCTAssertEqual(try DurableStore(directory: root).loadPendingAnswers(), [accepted])
    }

    func testExplicitRepairPreservesCorruptMetadataAndReopensCompleteDraft() throws {
        let root = try temporaryDirectory()
        let store = try DurableStore(directory: root)
        let id = UUID()
        let folder = try store.chunksDirectory(for: id)
        let originalAudio = Data([4, 2, 9])
        try originalAudio.write(to: folder.appendingPathComponent("0001.caf"))
        let metadata = folder.deletingLastPathComponent().appendingPathComponent("metadata.json")
        let originalMetadata = Data("{damaged metadata".utf8)
        try originalMetadata.write(to: metadata)
        var validated = try XCTUnwrap(store.loadDrafts().first)
        XCTAssertNotNil(validated.recoveryIssue)
        validated.chunks = [AudioChunk(filename: "0001.caf", duration: 2)]
        validated.duration = 2
        try store.repairDraft(validated)
        let reopened = try DurableStore(directory: root)
        let repaired = try XCTUnwrap(reopened.loadDrafts().first)
        XCTAssertEqual(repaired.id, id)
        XCTAssertEqual(repaired.chunks, validated.chunks)
        XCTAssertNil(repaired.recoveryIssue)
        XCTAssertNil(repaired.error)
        XCTAssertEqual(repaired.state, .draft)
        let backups = try FileManager.default.contentsOfDirectory(at: folder.deletingLastPathComponent(), includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("metadata.original-") }
        XCTAssertEqual(backups.count, 1)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(backups.first)), originalMetadata)
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent("0001.caf")), originalAudio)
        XCTAssertThrowsError(try reopened.repairDraft(repaired))
    }

    func testRepairRejectsTraversalOmittedAndMissingPartsWithoutReplacingMetadata() throws {
        let root = try temporaryDirectory()
        let store = try DurableStore(directory: root)
        let id = UUID()
        let folder = try store.chunksDirectory(for: id)
        try Data([1]).write(to: folder.appendingPathComponent("0001.caf"))
        try Data([2]).write(to: folder.appendingPathComponent("0002.caf"))
        let metadata = folder.deletingLastPathComponent().appendingPathComponent("metadata.json")
        let original = Data("broken".utf8)
        try original.write(to: metadata)
        var validated = try XCTUnwrap(store.loadDrafts().first)
        validated.duration = 2
        validated.chunks = [AudioChunk(filename: "../secret.caf", duration: 2)]
        XCTAssertThrowsError(try store.repairDraft(validated))
        validated.chunks = [AudioChunk(filename: "0001.caf", duration: 2)]
        XCTAssertThrowsError(try store.repairDraft(validated)) // Existing 0002 must not be omitted.
        XCTAssertEqual(try Data(contentsOf: metadata), original)
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.deletingLastPathComponent().path)
        XCTAssertFalse(files.contains { $0.hasPrefix("metadata.original-") })

        let missing = RecordingDraft(chunks: [AudioChunk(filename: "missing.caf", duration: 2)])
        try store.saveDraft(missing)
        var missingRepair = try XCTUnwrap(store.loadDrafts().first { $0.id == missing.id })
        missingRepair.duration = 2
        XCTAssertThrowsError(try store.repairDraft(missingRepair))
        let missingMetadata = root.appendingPathComponent("drafts").appendingPathComponent(missing.id.uuidString).appendingPathComponent("metadata.json")
        let preserved = try JSONDecoder().decode(RecordingDraft.self, from: Data(contentsOf: missingMetadata))
        XCTAssertEqual(preserved, missing)
    }

    func testPendingAnswersCannotMoveAcrossAccountsOrChangeQuestionSnapshot() throws {
        let root = try temporaryDirectory()
        let store = try DurableStore(directory: root)
        var answer = PendingAnswer(threadID: "same-thread", interactionID: "same-question", choice: "yes", deadline: .distantPast, serverIdentity: "account-A", questionFingerprint: "version-1")
        try store.savePendingAnswer(answer)
        answer.serverIdentity = "account-B"
        XCTAssertThrowsError(try store.savePendingAnswer(answer))
        answer.serverIdentity = "account-A"; answer.questionFingerprint = "version-2"
        XCTAssertThrowsError(try store.savePendingAnswer(answer))
        let otherAccount = PendingAnswer(threadID: "same-thread", interactionID: "same-question", choice: "no", deadline: .distantPast, serverIdentity: "account-B", questionFingerprint: "version-1")
        try store.savePendingAnswer(otherAccount)
        let reopened = try DurableStore(directory: root).loadPendingAnswers()
        XCTAssertEqual(Set(reopened.compactMap(\.serverIdentity)), Set(["account-A", "account-B"]))
        XCTAssertEqual(reopened.first { $0.serverIdentity == "account-A" }?.questionFingerprint, "version-1")
    }

    func testMissingChunkIsRecoverableButRequiresReviewBeforeDelivery() throws {
        let root = try temporaryDirectory()
        let store = try DurableStore(directory: root)
        let draft = RecordingDraft(state: .queued, chunks: [AudioChunk(filename: "lost.caf", duration: 2)])
        try store.saveDraft(draft)
        let recovered = try XCTUnwrap(DurableStore(directory: root).loadDrafts().first)
        XCTAssertEqual(recovered.id, draft.id)
        XCTAssertEqual(recovered.state, .draft)
        XCTAssertNotNil(recovered.recoveryIssue)
        XCTAssertEqual(recovered.chunks, draft.chunks)
    }

    func testAcceptanceRequiresDurableServerEvidence() throws {
        let root = try temporaryDirectory()
        let store = try DurableStore(directory: root)
        var draft = RecordingDraft(state: .accepted)
        XCTAssertThrowsError(try store.saveDraft(draft))
        draft.acceptanceReceipt = ""
        XCTAssertThrowsError(try store.saveDraft(draft))
        draft.acceptanceReceipt = "{\"ok\":true,\"delivery\":\"sent\"}"
        try store.saveDraft(draft)
        XCTAssertEqual(try DurableStore(directory: root).loadDrafts(), [draft])
        draft.state = .failed
        XCTAssertThrowsError(try store.saveDraft(draft))
        XCTAssertEqual(try DurableStore(directory: root).loadDrafts().first?.state, .accepted)
    }

    func testOfflineWaitingAnswerCanBeCancelledAfterDeadlineAndDuplicateTapIsRejected() throws {
        let store = try DurableStore(directory: temporaryDirectory())
        let answer = PendingAnswer(threadID: "t", interactionID: "i", choice: "Exact original choice", deadline: .distantPast)
        try store.savePendingAnswer(answer)
        let duplicate = PendingAnswer(threadID: "t", interactionID: "i", choice: "Exact original choice", deadline: .distantPast)
        XCTAssertThrowsError(try store.savePendingAnswer(duplicate))
        XCTAssertTrue(try store.cancelPendingAnswer(id: answer.id))
        XCTAssertTrue(try store.loadPendingAnswers().isEmpty)
    }
}
