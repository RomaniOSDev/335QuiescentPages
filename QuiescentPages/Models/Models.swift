import Foundation

struct Quote: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var text: String
    var translatedText: String
    var language: String
    var bookTitle: String
    var createdAt: Date
    var author: String
    var page: String
    var isFavorite: Bool

    init(
        id: UUID,
        text: String,
        translatedText: String,
        language: String,
        bookTitle: String,
        createdAt: Date,
        author: String = "",
        page: String = "",
        isFavorite: Bool = false
    ) {
        self.id = id
        self.text = text
        self.translatedText = translatedText
        self.language = language
        self.bookTitle = bookTitle
        self.createdAt = createdAt
        self.author = author
        self.page = page
        self.isFavorite = isFavorite
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        translatedText = try container.decode(String.self, forKey: .translatedText)
        language = try container.decode(String.self, forKey: .language)
        bookTitle = try container.decode(String.self, forKey: .bookTitle)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        author = try container.decodeIfPresent(String.self, forKey: .author) ?? ""
        page = try container.decodeIfPresent(String.self, forKey: .page) ?? ""
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }
}

struct MissedWord: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var word: String
    var language: String
    var lastSeenAt: Date
    var count: Int
}

struct TranslationOutcome: Equatable {
    let translatedText: String
    let coverage: Double
    let unknownWords: [String]

    var meetsSaveThreshold: Bool {
        coverage >= Translator.minimumCoverage
    }

    var coveragePercent: Int {
        Int((coverage * 100).rounded())
    }
}

enum TargetLanguage: String, CaseIterable, Identifiable, Codable, Hashable {
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .italian: return "Italian"
        }
    }

    var nativeHint: String {
        switch self {
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .italian: return "Italiano"
        }
    }

    static func resolved(_ code: String) -> TargetLanguage? {
        TargetLanguage(rawValue: code)
    }
}

enum LibraryDestination: String, CaseIterable, Identifiable, Hashable {
    case quotes
    case history
    case log
    case study

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quotes: return "Quotes"
        case .history: return "History"
        case .log: return "Stats"
        case .study: return "Study"
        }
    }

    var bannerName: String {
        switch self {
        case .quotes: return "BannerPen"
        case .history: return "BannerStack"
        case .log: return "BannerLamp"
        case .study: return "BannerStack"
        }
    }

    var symbolName: String {
        switch self {
        case .quotes: return "bookmark"
        case .history: return "books.vertical"
        case .log: return "chart.bar"
        case .study: return "text.book.closed"
        }
    }
}

enum QuoteSort: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case book
    case language

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: return "Newest"
        case .oldest: return "Oldest"
        case .book: return "Book"
        case .language: return "Language"
        }
    }
}

struct DayInsight: Identifiable, Equatable {
    var id: Date { day }
    let day: Date
    let count: Int
}

struct BookInsight: Identifiable, Equatable {
    var id: String { title }
    let title: String
    let count: Int
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension TargetLanguage {
    static func displayName(for code: String) -> String {
        TargetLanguage(rawValue: code)?.displayName ?? code.uppercased()
    }
}
