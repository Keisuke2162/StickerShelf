#if canImport(UIKit)
import SwiftUI
import Domain

public struct CalendarView: View {
    private let container: PresentationContainer
    private let router: Router
    @State private var viewModel: CalendarViewModel

    public init(container: PresentationContainer, router: Router) {
        self.container = container
        self.router = router
        self._viewModel = State(initialValue: CalendarViewModel(container: container))
    }

    public var body: some View {
        VStack(spacing: 12) {
            header
            stats
            weekdayHeader
            daysGrid
            if let day = viewModel.selectedDay {
                dayDetail(day: day)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ColorToken.boardBackground.ignoresSafeArea())
        .task { await viewModel.reload() }
        .task(id: router.selectedTab) {
            if router.selectedTab == .calendar { await viewModel.start() }
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width < -50 {
                        Task { await viewModel.moveMonth(by: 1) }
                    } else if value.translation.width > 50 {
                        Task { await viewModel.moveMonth(by: -1) }
                    }
                }
        )
    }

    private var header: some View {
        HStack {
            Text("カレンダー").font(FontToken.screenTitle()).foregroundStyle(ColorToken.ink)
            Spacer()
            Button { Task { await viewModel.moveMonth(by: -1) } } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 22).fill(ColorToken.surface))
                    .foregroundStyle(ColorToken.ink)
            }
            Text(verbatim: "\(viewModel.year)年 \(viewModel.month)月").font(FontToken.sectionTitle()).foregroundStyle(ColorToken.ink)
            Button { Task { await viewModel.moveMonth(by: 1) } } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 22).fill(ColorToken.surface))
                    .foregroundStyle(ColorToken.ink)
            }
        }
    }

    private var stats: some View {
        HStack(spacing: 8) {
            statCard(title: "今月読んだ", value: "\(viewModel.summary?.monthCount ?? 0)冊")
            statCard(title: "今年読んだ", value: "\(viewModel.summary?.yearCount ?? 0)冊")
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(FontToken.caption()).foregroundStyle(ColorToken.inkSecondary)
            Text(value).font(FontToken.statNumber()).foregroundStyle(ColorToken.ink)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(ColorToken.surface))
    }

    private var weekdayHeader: some View {
        let labels = ["日", "月", "火", "水", "木", "金", "土"]
        return HStack(spacing: 4) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                Text(label)
                    .font(FontToken.caption().weight(.bold))
                    .foregroundStyle(weekdayColor(index: index))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func weekdayColor(index: Int) -> Color {
        switch index {
        case 0: return ColorToken.sunday
        case 6: return ColorToken.saturday
        default: return ColorToken.inkSecondary
        }
    }

    private var daysGrid: some View {
        let days = viewModel.daysGrid()
        let rows = Array(stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0+7, days.count)]) })
        return VStack(spacing: 4) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 4) {
                    ForEach(Array(row.enumerated()), id: \.offset) { col, date in
                        if let date {
                            dayCell(date: date, col: col)
                        } else {
                            Color.clear.frame(maxWidth: .infinity).frame(height: 68)
                        }
                    }
                }
            }
        }
    }

    private func dayCell(date: Date, col: Int) -> some View {
        let books = viewModel.books(for: date)
        let dayNum = Calendar.current.component(.day, from: date)
        let isSelected = viewModel.selectedDay.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false

        return Button {
            viewModel.selectedDay = date
        } label: {
            VStack(spacing: 2) {
                HStack {
                    Text("\(dayNum)")
                        .font(FontToken.caption().weight(.bold))
                        .foregroundStyle(weekdayColor(index: col))
                    Spacer(minLength: 0)
                }
                .padding(.leading, 6)
                .padding(.top, 4)
                if let first = books.first {
                    CoverImageView(cover: first.cover, title: first.metadata.title, loader: { cover in (try? await container.coverImages.imageData(for: cover)) ?? nil })
                        .frame(width: 30, height: 42)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(.white, lineWidth: 1.5))
                        .shadow(color: ColorToken.ink.opacity(0.1), radius: 1, y: 1)
                } else {
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 68)
            .background(RoundedRectangle(cornerRadius: 10).fill(ColorToken.surface))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? ColorToken.ink : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private func dayDetail(day: Date) -> some View {
        let books = viewModel.books(for: day)
        let formatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "M月d日"
            return f
        }()
        return VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "\(formatter.string(from: day))に読んだ本")
                .font(FontToken.sectionTitle()).foregroundStyle(ColorToken.ink)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(books) { book in
                        Button {
                            router.detailBookID = book.id
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                CoverImageView(cover: book.cover, title: book.metadata.title, loader: { cover in (try? await container.coverImages.imageData(for: cover)) ?? nil })
                                    .frame(width: 30, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                                Text(book.metadata.title).font(FontToken.caption()).foregroundStyle(ColorToken.ink).lineLimit(2)
                                Text(book.metadata.authors.joined(separator: ", ")).font(FontToken.caption()).foregroundStyle(ColorToken.inkSecondary).lineLimit(1)
                            }
                            .frame(width: 110, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

#endif
