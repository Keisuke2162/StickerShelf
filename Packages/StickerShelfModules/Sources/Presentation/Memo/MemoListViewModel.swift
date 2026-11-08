#if canImport(UIKit)
import Foundation
import Observation
import Domain
import Application

@MainActor
@Observable
public final class MemoListViewModel {
    public private(set) var memos: [TitleMemo] = []
    public var input: String = ""
    public var errorMessage: String?

    private let container: PresentationContainer

    public init(container: PresentationContainer) {
        self.container = container
    }

    public func start() async {
        for await _ in container.memoChanges() {
            await reload()
        }
    }

    public func reload() async {
        do {
            memos = try await container.fetchMemos.execute()
        } catch {
            errorMessage = DomainErrorMessage.describe(error)
        }
    }

    /// 現在の入力をメモに追加し、入力をクリアする。空文字は無視する。
    public func submitCurrentInput() async {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            _ = try await container.addMemo.execute(title: trimmed, now: Date())
            input = ""
        } catch {
            errorMessage = DomainErrorMessage.describe(error)
        }
    }

    public func delete(id: UUID) async {
        do {
            try await container.deleteMemo.execute(id: id)
        } catch {
            errorMessage = DomainErrorMessage.describe(error)
        }
    }
}

#endif
