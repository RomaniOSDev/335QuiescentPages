import Combine
import Foundation

final class Store: ObservableObject {
    private enum Keys {
        static let quotes = "quotes"
        static let books = "books"
        static let preferredLanguages = "preferredLanguages"
        static let lastTranslationDate = "lastTranslationDate"
        static let lastViewedTranslationID = "lastViewedTranslationID"
        static let lastAccessedDate = "lastAccessedDate"
        static let hasSeenLanguageSetup = "hasSeenLanguageSetup"
        static let hasSeededCatalog = "hasSeededCatalog"
        static let missedWords = "missedWords"
        static let dailyQuoteID = "dailyQuoteID"
        static let dailyQuoteDay = "dailyQuoteDay"
        static let remindersEnabled = "remindersEnabled"
    }

    @Published var quotes: [Quote] = []
    @Published var books: [Book] = []
    @Published var preferredLanguages: [String] = []
    @Published var lastTranslationDate: Date?
    @Published var lastViewedTranslationID: UUID?
    @Published var lastAccessedDate: Date?
    @Published var hasSeenLanguageSetup: Bool = false
    @Published var missedWords: [MissedWord] = []
    @Published var dailyQuoteID: UUID?
    @Published var dailyQuoteDay: Date?
    @Published var remindersEnabled: Bool = false

    init() {
        loadAll()
        migrateBooksIfNeeded()
        seedCatalogIfNeeded()
        markAccessed()
        refreshDailyQuoteIfNeeded()
    }

    var sortedQuotes: [Quote] {
        quotes.sorted { $0.createdAt > $1.createdAt }
    }

    var sortedBooks: [Book] {
        books.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var sortedMissedWords: [MissedWord] {
        missedWords.sorted { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.word.localizedCaseInsensitiveCompare(rhs.word) == .orderedAscending
            }
            return lhs.count > rhs.count
        }
    }

    var needsLanguageSetup: Bool {
        !hasSeenLanguageSetup || preferredLanguages.isEmpty
    }

    var dueQuotes: [Quote] {
        let now = Date()
        return quotes.filter { quote in
            guard let due = quote.nextReviewAt else { return quote.reviewCount == 0 }
            return due <= now
        }
        .sorted { lhs, rhs in
            let l = lhs.nextReviewAt ?? .distantPast
            let r = rhs.nextReviewAt ?? .distantPast
            return l < r
        }
    }

    func quote(id: UUID) -> Quote? {
        quotes.first { $0.id == id }
    }

    func book(id: UUID) -> Book? {
        books.first { $0.id == id }
    }

    func book(titled title: String) -> Book? {
        books.first { $0.title.caseInsensitiveCompare(title) == .orderedSame }
    }

    func quotes(forBookID id: UUID) -> [Quote] {
        quotes.filter { $0.bookID == id }.sorted { $0.createdAt > $1.createdAt }
    }

    func quoteOfTheDay() -> Quote? {
        guard let dailyQuoteID else { return nil }
        return quote(id: dailyQuoteID)
    }

    func availableLanguages() -> [TargetLanguage] {
        let preferred = TargetLanguage.allCases.filter { preferredLanguages.contains($0.rawValue) }
        return preferred.isEmpty ? TargetLanguage.allCases : preferred
    }

    func languagesInLibrary() -> [TargetLanguage] {
        TargetLanguage.allCases.filter { language in
            quotes.contains { $0.language == language.rawValue }
        }
    }

    func distinctBookTitles() -> [String] {
        Array(Set(quotes.map(\.bookTitle))).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    @discardableResult
    func upsertBook(_ book: Book) -> Book {
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            books[index] = book
        } else if let existing = books.firstIndex(where: { $0.title.caseInsensitiveCompare(book.title) == .orderedSame }) {
            var merged = books[existing]
            if merged.author.isEmpty { merged.author = book.author }
            if merged.notes.isEmpty { merged.notes = book.notes }
            books[existing] = merged
            persistAll()
            return merged
        } else {
            books.insert(book, at: 0)
        }
        persistAll()
        return book
    }

    func deleteBook(id: UUID) {
        books.removeAll { $0.id == id }
        for index in quotes.indices where quotes[index].bookID == id {
            quotes[index].bookID = nil
        }
        persistAll()
    }

    func ensureBook(title: String, author: String) -> Book {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = book(titled: trimmed) {
            if existing.author.isEmpty, !author.isEmpty {
                var updated = existing
                updated.author = author
                return upsertBook(updated)
            }
            return existing
        }
        let tone = abs(trimmed.hashValue) % 4
        return upsertBook(Book(title: trimmed, author: author, shelfTone: tone))
    }

    func upsert(_ quote: Quote) {
        var item = quote
        let book = ensureBook(title: item.bookTitle, author: item.author)
        item.bookID = book.id
        item.bookTitle = book.title
        if item.author.isEmpty {
            item.author = book.author
        }
        if item.nextReviewAt == nil {
            item.nextReviewAt = Date()
        }
        if let index = quotes.firstIndex(where: { $0.id == item.id }) {
            quotes[index] = item
        } else {
            quotes.insert(item, at: 0)
        }
        lastTranslationDate = Date()
        persistAll()
        refreshDailyQuoteIfNeeded()
    }

    func delete(ids: [UUID]) {
        guard !ids.isEmpty else { return }
        quotes.removeAll { ids.contains($0.id) }
        if let viewed = lastViewedTranslationID, ids.contains(viewed) {
            lastViewedTranslationID = nil
        }
        persistAll()
        refreshDailyQuoteIfNeeded()
    }

    func delete(_ quote: Quote) {
        delete(ids: [quote.id])
    }

    func toggleFavorite(_ id: UUID) {
        guard let index = quotes.firstIndex(where: { $0.id == id }) else { return }
        quotes[index].isFavorite.toggle()
        persistAll()
    }

    func markViewed(_ id: UUID) {
        lastViewedTranslationID = id
        persistAll()
    }

    func markAccessed() {
        lastAccessedDate = Date()
        persistValue(lastAccessedDate, key: Keys.lastAccessedDate)
    }

    func completeLanguageSetup(_ codes: [String]) {
        preferredLanguages = codes
        hasSeenLanguageSetup = true
        persistAll()
    }

    func updatePreferredLanguages(_ codes: [String]) {
        preferredLanguages = codes
        persistAll()
    }

    func setRemindersEnabled(_ enabled: Bool) {
        remindersEnabled = enabled
        persistAll()
    }

    func recordUnknownWords(_ words: [String], language: String, exampleQuoteID: UUID? = nil) {
        let trimmed = words
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !trimmed.isEmpty else { return }
        let now = Date()
        for word in trimmed {
            if let index = missedWords.firstIndex(where: {
                $0.language == language && $0.word.caseInsensitiveCompare(word) == .orderedSame
            }) {
                missedWords[index].count += 1
                missedWords[index].lastSeenAt = now
                missedWords[index].word = word
                if missedWords[index].exampleQuoteID == nil {
                    missedWords[index].exampleQuoteID = exampleQuoteID
                }
            } else {
                missedWords.append(
                    MissedWord(
                        id: UUID(),
                        word: word,
                        language: language,
                        lastSeenAt: now,
                        count: 1,
                        exampleQuoteID: exampleQuoteID
                    )
                )
            }
        }
        persistAll()
    }

    func deleteMissedWords(ids: [UUID]) {
        missedWords.removeAll { ids.contains($0.id) }
        persistAll()
    }

    func applyReview(quoteID: UUID, grade: ReviewGrade) {
        guard let index = quotes.firstIndex(where: { $0.id == quoteID }) else { return }
        var item = quotes[index]
        var ease = max(1.3, item.easeFactor)
        var interval = max(item.intervalDays, 0)

        switch grade {
        case .again:
            interval = 0
            ease = max(1.3, ease - 0.2)
            item.nextReviewAt = Date().addingTimeInterval(10 * 60)
        case .hard:
            interval = max(1, interval * 1.2)
            ease = max(1.3, ease - 0.05)
            item.nextReviewAt = Date().addingTimeInterval(interval * 86_400)
        case .good:
            interval = interval < 1 ? 1 : interval * ease
            item.nextReviewAt = Date().addingTimeInterval(interval * 86_400)
        case .easy:
            interval = interval < 1 ? 2 : interval * ease * 1.3
            ease += 0.05
            item.nextReviewAt = Date().addingTimeInterval(interval * 86_400)
        }

        item.intervalDays = interval
        item.easeFactor = ease
        item.reviewCount += 1
        quotes[index] = item
        persistAll()
    }

    func languageCounts() -> [(TargetLanguage, Int)] {
        TargetLanguage.allCases.compactMap { language in
            let count = quotes.filter { $0.language == language.rawValue }.count
            return count > 0 ? (language, count) : nil
        }
    }

    func dayInsights(lastDays days: Int) -> [DayInsight] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let span = max(days, 1)
        return (0..<span).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return nil
            }
            let count = quotes.filter { calendar.isDate($0.createdAt, inSameDayAs: day) }.count
            return DayInsight(day: day, count: count)
        }
    }

    func bookCounts() -> [BookInsight] {
        Dictionary(grouping: quotes, by: \.bookTitle)
            .map { BookInsight(title: $0.key, count: $0.value.count) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                return lhs.count > rhs.count
            }
    }

    func currentStreak() -> Int {
        let calendar = Calendar.current
        let daysWithQuotes = Set(quotes.map { calendar.startOfDay(for: $0.createdAt) })
        guard !daysWithQuotes.isEmpty else { return 0 }
        var cursor = calendar.startOfDay(for: Date())
        if !daysWithQuotes.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
            if !daysWithQuotes.contains(cursor) { return 0 }
        }
        var streak = 0
        while daysWithQuotes.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    func translations(inLastDays days: Int) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let offset = -(max(days, 1) - 1)
        guard let start = calendar.date(byAdding: .day, value: offset, to: today) else {
            return 0
        }
        return quotes.filter { $0.createdAt >= start }.count
    }

    func glossaryExamples(for word: MissedWord) -> [Quote] {
        if let id = word.exampleQuoteID, let quote = quote(id: id) {
            return [quote]
        }
        return quotes.filter {
            $0.language == word.language && $0.text.localizedCaseInsensitiveContains(word.word)
        }.prefix(3).map { $0 }
    }

    func refreshDailyQuoteIfNeeded() {
        guard !quotes.isEmpty else {
            if dailyQuoteID != nil || dailyQuoteDay != nil {
                dailyQuoteID = nil
                dailyQuoteDay = nil
                persistAll()
            }
            return
        }
        let today = Calendar.current.startOfDay(for: Date())
        if let storedDay = dailyQuoteDay,
           Calendar.current.isDate(storedDay, inSameDayAs: today),
           let id = dailyQuoteID,
           quotes.contains(where: { $0.id == id }) {
            return
        }
        var hasher = Hasher()
        hasher.combine(Int(today.timeIntervalSince1970))
        let raw = hasher.finalize()
        let index = (raw & Int.max) % quotes.count
        dailyQuoteID = quotes[index].id
        dailyQuoteDay = today
        persistAll()
    }

    func resetAllData() {
        quotes = []
        books = []
        preferredLanguages = []
        lastTranslationDate = nil
        lastViewedTranslationID = nil
        lastAccessedDate = nil
        hasSeenLanguageSetup = false
        missedWords = []
        dailyQuoteID = nil
        dailyQuoteDay = nil
        remindersEnabled = false
        ReminderScheduler.apply(enabled: false)

        let defaults = UserDefaults.standard
        [
            Keys.quotes, Keys.books, Keys.preferredLanguages, Keys.lastTranslationDate,
            Keys.lastViewedTranslationID, Keys.lastAccessedDate, Keys.hasSeenLanguageSetup,
            Keys.hasSeededCatalog, Keys.missedWords, Keys.dailyQuoteID, Keys.dailyQuoteDay,
            Keys.remindersEnabled
        ].forEach { defaults.removeObject(forKey: $0) }

        seedCatalogIfNeeded(force: true)
        NotificationCenter.default.post(name: Notification.Name("dataReset"), object: nil)
    }

    private func seedCatalogIfNeeded(force: Bool = false) {
        let already = UserDefaults.standard.bool(forKey: Keys.hasSeededCatalog)
        guard force || !already else { return }

        var bookMap: [String: Book] = [:]
        for item in SeedCatalog.books {
            let book = Book(
                title: item.title,
                author: item.author,
                notes: item.notes,
                shelfTone: item.tone
            )
            bookMap[item.title] = upsertBook(book)
        }

        for seed in SeedCatalog.quotes {
            let book = bookMap[seed.bookTitle] ?? ensureBook(title: seed.bookTitle, author: seed.author)
            let quote = Quote(
                text: seed.text,
                translatedText: seed.translatedText,
                language: seed.language,
                bookTitle: book.title,
                bookID: book.id,
                createdAt: Date().addingTimeInterval(-Double.random(in: 86_400...604_800)),
                author: seed.author,
                page: seed.page,
                notes: seed.notes,
                nextReviewAt: Date(),
                isSeed: true
            )
            if quotes.contains(where: { $0.text == quote.text && $0.language == quote.language }) == false {
                quotes.append(quote)
            }
        }

        UserDefaults.standard.set(true, forKey: Keys.hasSeededCatalog)
        persistAll()
        refreshDailyQuoteIfNeeded()
    }

    private func migrateBooksIfNeeded() {
        if books.isEmpty && !quotes.isEmpty {
            for quote in quotes {
                _ = ensureBook(title: quote.bookTitle, author: quote.author)
            }
        }
        for index in quotes.indices {
            if quotes[index].bookID == nil {
                let book = ensureBook(title: quotes[index].bookTitle, author: quotes[index].author)
                quotes[index].bookID = book.id
            }
            if quotes[index].nextReviewAt == nil {
                quotes[index].nextReviewAt = quotes[index].createdAt
            }
        }
        persistAll()
    }

    private func persistAll() {
        persistValue(quotes, key: Keys.quotes)
        persistValue(books, key: Keys.books)
        persistValue(preferredLanguages, key: Keys.preferredLanguages)
        persistValue(lastTranslationDate, key: Keys.lastTranslationDate)
        persistValue(lastViewedTranslationID, key: Keys.lastViewedTranslationID)
        persistValue(lastAccessedDate, key: Keys.lastAccessedDate)
        persistValue(hasSeenLanguageSetup, key: Keys.hasSeenLanguageSetup)
        persistValue(missedWords, key: Keys.missedWords)
        persistValue(dailyQuoteID, key: Keys.dailyQuoteID)
        persistValue(dailyQuoteDay, key: Keys.dailyQuoteDay)
        persistValue(remindersEnabled, key: Keys.remindersEnabled)
    }

    private func persistValue<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func loadValue<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func loadAll() {
        quotes = loadValue([Quote].self, key: Keys.quotes) ?? []
        books = loadValue([Book].self, key: Keys.books) ?? []
        preferredLanguages = loadValue([String].self, key: Keys.preferredLanguages) ?? []
        lastTranslationDate = loadValue(Date?.self, key: Keys.lastTranslationDate) ?? nil
        lastViewedTranslationID = loadValue(UUID?.self, key: Keys.lastViewedTranslationID) ?? nil
        lastAccessedDate = loadValue(Date?.self, key: Keys.lastAccessedDate) ?? nil
        hasSeenLanguageSetup = loadValue(Bool.self, key: Keys.hasSeenLanguageSetup) ?? false
        missedWords = loadValue([MissedWord].self, key: Keys.missedWords) ?? []
        dailyQuoteID = loadValue(UUID?.self, key: Keys.dailyQuoteID) ?? nil
        dailyQuoteDay = loadValue(Date?.self, key: Keys.dailyQuoteDay) ?? nil
        remindersEnabled = loadValue(Bool.self, key: Keys.remindersEnabled) ?? false
    }
}
