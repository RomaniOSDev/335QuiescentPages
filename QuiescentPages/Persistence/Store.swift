import Combine
import Foundation

final class Store: ObservableObject {
    private enum Keys {
        static let quotes = "quotes"
        static let preferredLanguages = "preferredLanguages"
        static let lastTranslationDate = "lastTranslationDate"
        static let translationHistory = "translationHistory"
        static let lastViewedTranslationID = "lastViewedTranslationID"
        static let lastAccessedDate = "lastAccessedDate"
        static let hasSeenLanguageSetup = "hasSeenLanguageSetup"
        static let missedWords = "missedWords"
        static let dailyQuoteID = "dailyQuoteID"
        static let dailyQuoteDay = "dailyQuoteDay"
        static let remindersEnabled = "remindersEnabled"
    }

    @Published var quotes: [Quote] = []
    @Published var preferredLanguages: [String] = []
    @Published var lastTranslationDate: Date?
    @Published var translationHistory: [Quote] = []
    @Published var lastViewedTranslationID: UUID?
    @Published var lastAccessedDate: Date?
    @Published var hasSeenLanguageSetup: Bool = false
    @Published var missedWords: [MissedWord] = []
    @Published var dailyQuoteID: UUID?
    @Published var dailyQuoteDay: Date?
    @Published var remindersEnabled: Bool = false

    init() {
        loadAll()
        markAccessed()
        refreshDailyQuoteIfNeeded()
    }

    var sortedQuotes: [Quote] {
        quotes.sorted { $0.createdAt > $1.createdAt }
    }

    var sortedHistory: [Quote] {
        translationHistory.sorted { $0.createdAt > $1.createdAt }
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

    func quote(id: UUID) -> Quote? {
        quotes.first { $0.id == id } ?? translationHistory.first { $0.id == id }
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

    func upsert(_ quote: Quote) {
        if let index = quotes.firstIndex(where: { $0.id == quote.id }) {
            quotes[index] = quote
        } else {
            quotes.insert(quote, at: 0)
        }
        if let index = translationHistory.firstIndex(where: { $0.id == quote.id }) {
            translationHistory[index] = quote
        } else {
            translationHistory.insert(quote, at: 0)
        }
        lastTranslationDate = Date()
        persistAll()
        refreshDailyQuoteIfNeeded()
    }

    func delete(ids: [UUID]) {
        guard !ids.isEmpty else { return }
        quotes.removeAll { ids.contains($0.id) }
        translationHistory.removeAll { ids.contains($0.id) }
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
        if let historyIndex = translationHistory.firstIndex(where: { $0.id == id }) {
            translationHistory[historyIndex].isFavorite = quotes[index].isFavorite
        }
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

    func recordUnknownWords(_ words: [String], language: String) {
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
            } else {
                missedWords.append(
                    MissedWord(id: UUID(), word: word, language: language, lastSeenAt: now, count: 1)
                )
            }
        }
        persistAll()
    }

    func deleteMissedWords(ids: [UUID]) {
        missedWords.removeAll { ids.contains($0.id) }
        persistAll()
    }

    func languageCounts() -> [(TargetLanguage, Int)] {
        TargetLanguage.allCases.compactMap { language in
            let count = quotes.filter { $0.language == language.rawValue }.count
            return count > 0 ? (language, count) : nil
        }
    }

    func lastSevenDays() -> [DayInsight] {
        dayInsights(lastDays: 7)
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
        preferredLanguages = []
        lastTranslationDate = nil
        translationHistory = []
        lastViewedTranslationID = nil
        lastAccessedDate = nil
        hasSeenLanguageSetup = false
        missedWords = []
        dailyQuoteID = nil
        dailyQuoteDay = nil
        remindersEnabled = false
        ReminderScheduler.apply(enabled: false)

        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Keys.quotes)
        defaults.removeObject(forKey: Keys.preferredLanguages)
        defaults.removeObject(forKey: Keys.lastTranslationDate)
        defaults.removeObject(forKey: Keys.translationHistory)
        defaults.removeObject(forKey: Keys.lastViewedTranslationID)
        defaults.removeObject(forKey: Keys.lastAccessedDate)
        defaults.removeObject(forKey: Keys.hasSeenLanguageSetup)
        defaults.removeObject(forKey: Keys.missedWords)
        defaults.removeObject(forKey: Keys.dailyQuoteID)
        defaults.removeObject(forKey: Keys.dailyQuoteDay)
        defaults.removeObject(forKey: Keys.remindersEnabled)

        NotificationCenter.default.post(name: Notification.Name("dataReset"), object: nil)
    }

    private func persistAll() {
        persistValue(quotes, key: Keys.quotes)
        persistValue(preferredLanguages, key: Keys.preferredLanguages)
        persistValue(lastTranslationDate, key: Keys.lastTranslationDate)
        persistValue(translationHistory, key: Keys.translationHistory)
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
        preferredLanguages = loadValue([String].self, key: Keys.preferredLanguages) ?? []
        lastTranslationDate = loadValue(Date?.self, key: Keys.lastTranslationDate) ?? nil
        translationHistory = loadValue([Quote].self, key: Keys.translationHistory) ?? quotes
        lastViewedTranslationID = loadValue(UUID?.self, key: Keys.lastViewedTranslationID) ?? nil
        lastAccessedDate = loadValue(Date?.self, key: Keys.lastAccessedDate) ?? nil
        hasSeenLanguageSetup = loadValue(Bool.self, key: Keys.hasSeenLanguageSetup) ?? false
        missedWords = loadValue([MissedWord].self, key: Keys.missedWords) ?? []
        dailyQuoteID = loadValue(UUID?.self, key: Keys.dailyQuoteID) ?? nil
        dailyQuoteDay = loadValue(Date?.self, key: Keys.dailyQuoteDay) ?? nil
        remindersEnabled = loadValue(Bool.self, key: Keys.remindersEnabled) ?? false
        if translationHistory.isEmpty && !quotes.isEmpty {
            translationHistory = quotes
        }
    }
}
