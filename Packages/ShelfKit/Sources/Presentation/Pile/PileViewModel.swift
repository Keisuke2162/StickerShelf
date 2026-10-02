#if canImport(UIKit)
import Foundation
import Observation
import Domain
import Application

@MainActor
@Observable
public final class PileViewModel {
    public enum Display: Hashable { case pile, list }

    public private(set) var books: [Book] = []
    public private(set) var statistics: TsundokuStatistics.Snapshot = .init(count: 0, averageDays: 0, addedThisMonth: 0)
    public private(set) var isLoading = false
    public var display: Display = .pile
    public var errorMessage: String?

    private let container: PresentationContainer
    private let calendar: Calendar

    public init(container: PresentationContainer, calendar: Calendar = .current) {
        self.container = container
        self.calendar = calendar
    }

    public func start() async {
        for await _ in container.bookChanges() {
            await reload()
        }
    }

    public func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let out = try await container.fetchPile.execute(now: Date())
            books = out.books
            statistics = out.statistics
        } catch {
            errorMessage = String(describing: error)
        }
    }

    public func daysInPile(for book: Book) -> Int {
        let today = calendar.startOfDay(for: Date())
        let base = calendar.startOfDay(for: book.purchase.purchasedAt ?? book.addedAt)
        return max(0, calendar.dateComponents([.day], from: base, to: today).day ?? 0)
    }

    public func startReading(id: BookID) async {
        do { _ = try await container.changeStatus.execute(id: id, newStatus: .reading, now: Date()) } catch { errorMessage = String(describing: error) }
    }

    public func markFinished(id: BookID) async {
        do { _ = try await container.changeStatus.execute(id: id, newStatus: .finished, now: Date()) } catch { errorMessage = String(describing: error) }
    }

    public func deleteBook(id: BookID) async {
        do { try await container.deleteBook.execute(id: id) } catch { errorMessage = String(describing: error) }
    }
}

#endif
