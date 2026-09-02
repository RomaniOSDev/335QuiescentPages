import Charts
import SwiftUI

private enum ActivityRange: Int, CaseIterable, Identifiable {
    case week = 7
    case month = 30

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .week: return "7 Days"
        case .month: return "30 Days"
        }
    }
}

struct LogWorkspace: View {
    @EnvironmentObject private var store: Store
    @State private var path = NavigationPath()
    @State private var draft: QuoteDraft?
    @State private var activityRange: ActivityRange = .week

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 12) {
                header
                LibraryBanner(imageName: LibraryDestination.log.bannerName)
                ScrollView {
                    ParchmentStage {
                        logBody
                    }
                    .padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .background(DisableNavBarHits())
            .navigationDestination(for: UUID.self) { quoteID in
                QuoteDetailView(quoteID: quoteID, onEdit: { draft = .edit(quoteID) })
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $draft) { item in
            QuoteEditorView(draft: item)
                .environmentObject(store)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("dataReset"))) { _ in
            path = NavigationPath()
            draft = nil
            activityRange = .week
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Statistics")
                .font(.system(.largeTitle, design: .serif).weight(.semibold))
                .foregroundColor(Color("AppPrimary"))
            Text("How the shelves have grown")
                .font(.system(.subheadline, design: .serif))
                .foregroundColor(Color.white.opacity(0.9))
        }
    }

    @ViewBuilder
    private var logBody: some View {
        if store.sortedQuotes.isEmpty {
            EmptyQuotesPanel(
                title: "No Statistics Yet",
                detail: "Translate a quote and the charts will keep a dated account."
            )
            .frame(minHeight: 260)
        } else {
            VStack(alignment: .leading, spacing: 18) {
                Text(insightParagraph)
                    .font(.system(.body, design: .serif))
                    .foregroundColor(Color.primary)

                summaryGrid

                LedgerDivider()

                activitySection

                LedgerDivider()

                languageSection

                LedgerDivider()

                booksSection

                if let last = store.lastTranslationDate {
                    Text("Last translation \(last.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(.caption, design: .serif))
                        .foregroundColor(Color.primary.opacity(0.65))
                }

                LedgerDivider()

                Text("Chronological")
                    .font(.system(.headline, design: .serif))
                    .foregroundColor(Color("AppPrimary"))

                ForEach(store.sortedHistory) { quote in
                    Button {
                        path.append(quote.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(quote.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(.caption, design: .serif))
                                .foregroundColor(Color("AppPrimary"))
                            Text(quote.bookTitle)
                                .font(.system(.headline, design: .serif))
                                .foregroundColor(Color.primary)
                            Text(quote.translatedText)
                                .font(.system(.subheadline, design: .serif))
                                .foregroundColor(Color.primary.opacity(0.75))
                                .lineLimit(2)
                            LedgerDivider()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var insightParagraph: String {
        let total = store.quotes.count
        let week = store.translations(inLastDays: 7)
        let counts = store.languageCounts()
        let lead = counts.max(by: { $0.1 < $1.1 })
        let streak = store.currentStreak()
        var parts: [String] = []
        parts.append("\(total) translation\(total == 1 ? "" : "s") recorded.")
        if let lead {
            parts.append("\(lead.0.displayName) leads with \(lead.1).")
        }
        parts.append("Last 7 days: \(week) new \(week == 1 ? "entry" : "entries").")
        if streak > 0 {
            parts.append("Streak: \(streak) day\(streak == 1 ? "" : "s").")
        }
        if let viewed = store.lastViewedTranslationID, let quote = store.quote(id: viewed) {
            parts.append("Last opened: \(quote.bookTitle).")
        }
        return parts.joined(separator: " ")
    }

    private var summaryGrid: some View {
        let books = store.bookCounts().count
        let week = store.translations(inLastDays: 7)
        let streak = store.currentStreak()
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            StatTile(title: "Quotes", value: "\(store.quotes.count)")
            StatTile(title: "This Week", value: "\(week)")
            StatTile(title: "Books", value: "\(books)")
            StatTile(title: "Streak", value: "\(streak)")
        }
    }

    private var activitySection: some View {
        let days = store.dayInsights(lastDays: activityRange.rawValue)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Activity")
                    .font(.system(.headline, design: .serif))
                    .foregroundColor(Color("AppPrimary"))
                Spacer()
                HStack(spacing: 6) {
                    ForEach(ActivityRange.allCases) { range in
                        let isOn = activityRange == range
                        Button {
                            activityRange = range
                        } label: {
                            Text(range.title)
                                .font(.system(.caption, design: .serif).weight(.semibold))
                                .foregroundColor(isOn ? Color.white : Color("AppPrimary"))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background {
                                    Capsule()
                                        .fill(
                                            isOn
                                                ? AnyShapeStyle(
                                                    LinearGradient(
                                                        colors: [Color("AppPrimary"), Color("AppAccent")],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                : AnyShapeStyle(Color("AppSurface").opacity(0.25))
                                        )
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if activityRange == .week {
                Chart(days) { item in
                    BarMark(
                        x: .value("Day", item.day, unit: .day),
                        y: .value("Quotes", item.count)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color("AppPrimary"), Color("AppAccent")],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4))
                            .foregroundStyle(Color("AppPrimary").opacity(0.15))
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                            .font(.system(.caption2, design: .serif))
                            .foregroundStyle(Color.primary.opacity(0.7))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4))
                            .foregroundStyle(Color("AppPrimary").opacity(0.12))
                        AxisValueLabel()
                            .font(.system(.caption2, design: .serif))
                            .foregroundStyle(Color.primary.opacity(0.65))
                    }
                }
                .chartYScale(domain: .automatic(includesZero: true))
                .frame(height: 168)
            } else {
                Chart(days) { item in
                    AreaMark(
                        x: .value("Day", item.day, unit: .day),
                        y: .value("Quotes", item.count)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color("AppAccent").opacity(0.35), Color("AppPrimary").opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    LineMark(
                        x: .value("Day", item.day, unit: .day),
                        y: .value("Quotes", item.count)
                    )
                    .foregroundStyle(Color("AppPrimary"))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    PointMark(
                        x: .value("Day", item.day, unit: .day),
                        y: .value("Quotes", item.count)
                    )
                    .foregroundStyle(Color("AppAccent"))
                    .symbolSize(item.count == 0 ? 0 : 28)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 5)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4))
                            .foregroundStyle(Color("AppPrimary").opacity(0.15))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
                            .font(.system(.caption2, design: .serif))
                            .foregroundStyle(Color.primary.opacity(0.7))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4))
                            .foregroundStyle(Color("AppPrimary").opacity(0.12))
                        AxisValueLabel()
                            .font(.system(.caption2, design: .serif))
                            .foregroundStyle(Color.primary.opacity(0.65))
                    }
                }
                .chartYScale(domain: .automatic(includesZero: true))
                .frame(height: 168)
            }
        }
    }

    private var languageSection: some View {
        let counts = store.languageCounts()
        let total = max(counts.reduce(0) { $0 + $1.1 }, 1)
        return VStack(alignment: .leading, spacing: 12) {
            Text("By Language")
                .font(.system(.headline, design: .serif))
                .foregroundColor(Color("AppPrimary"))

            HStack(alignment: .center, spacing: 16) {
                LanguageShareRing(slices: counts)
                    .frame(width: 112, height: 112)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(counts, id: \.0) { language, count in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(language.chartColor)
                                .frame(width: 8, height: 8)
                            Text(language.displayName)
                                .font(.system(.subheadline, design: .serif))
                            Spacer()
                            Text("\(count)")
                                .font(.system(.subheadline, design: .serif).weight(.semibold))
                                .foregroundColor(Color("AppPrimary"))
                            Text("\(Int((Double(count) / Double(total) * 100).rounded()))%")
                                .font(.system(.caption, design: .serif))
                                .foregroundColor(Color.primary.opacity(0.55))
                                .frame(width: 36, alignment: .trailing)
                        }
                    }
                }
            }

            Chart(counts, id: \.0) { language, count in
                BarMark(
                    x: .value("Count", count),
                    y: .value("Language", language.displayName)
                )
                .foregroundStyle(language.chartColor)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4))
                        .foregroundStyle(Color("AppPrimary").opacity(0.12))
                    AxisValueLabel()
                        .font(.system(.caption2, design: .serif))
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.system(.caption, design: .serif))
                }
            }
            .frame(height: max(72, CGFloat(counts.count) * 36))
        }
    }

    private var booksSection: some View {
        let books = Array(store.bookCounts().prefix(6))
        return VStack(alignment: .leading, spacing: 12) {
            Text("By Book")
                .font(.system(.headline, design: .serif))
                .foregroundColor(Color("AppPrimary"))

            Chart(books) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Book", item.title)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color("AppPrimary"), Color("AppAccent")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4))
                        .foregroundStyle(Color("AppPrimary").opacity(0.12))
                    AxisValueLabel()
                        .font(.system(.caption2, design: .serif))
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.system(.caption, design: .serif))
                        .foregroundStyle(Color.primary.opacity(0.85))
                }
            }
            .frame(height: max(80, CGFloat(books.count) * 38))
        }
    }
}

private struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.caption, design: .serif).weight(.semibold))
                .foregroundColor(Color("AppPrimary"))
            Text(value)
                .font(.system(.title, design: .serif).weight(.semibold))
                .foregroundColor(Color.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color("AppSurface").opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct LanguageShareRing: View {
    let slices: [(TargetLanguage, Int)]

    var body: some View {
        let total = max(slices.reduce(0) { $0 + $1.1 }, 1)
        ZStack {
            Circle()
                .stroke(Color("AppSurface").opacity(0.35), lineWidth: 16)
            ForEach(Array(sliceRanges(total: total).enumerated()), id: \.offset) { _, item in
                Circle()
                    .trim(from: item.start, to: item.end)
                    .stroke(item.language.chartColor, style: StrokeStyle(lineWidth: 16, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 0) {
                Text("\(slices.reduce(0) { $0 + $1.1 })")
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .foregroundColor(Color("AppPrimary"))
                Text("total")
                    .font(.system(.caption2, design: .serif))
                    .foregroundColor(Color.primary.opacity(0.55))
            }
        }
        .padding(8)
    }

    private func sliceRanges(total: Int) -> [(language: TargetLanguage, start: CGFloat, end: CGFloat)] {
        var cursor: CGFloat = 0
        return slices.map { language, count in
            let start = cursor
            cursor += CGFloat(count) / CGFloat(total)
            return (language, start, cursor)
        }
    }
}

private extension TargetLanguage {
    var chartColor: Color {
        switch self {
        case .spanish: return Color("AppPrimary")
        case .french: return Color("AppAccent")
        case .german: return Color("AppPrimary").opacity(0.55)
        case .italian: return Color("AppAccent").opacity(0.62)
        }
    }
}
