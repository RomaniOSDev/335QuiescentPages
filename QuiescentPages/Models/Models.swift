import Foundation

struct Book: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var title: String
    var author: String
    var notes: String
    var createdAt: Date
    var shelfTone: Int

    init(
        id: UUID = UUID(),
        title: String,
        author: String = "",
        notes: String = "",
        createdAt: Date = Date(),
        shelfTone: Int = 0
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.notes = notes
        self.createdAt = createdAt
        self.shelfTone = shelfTone
    }
}

struct Quote: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var text: String
    var translatedText: String
    var language: String
    var bookTitle: String
    var bookID: UUID?
    var createdAt: Date
    var author: String
    var page: String
    var isFavorite: Bool
    var notes: String
    var intervalDays: Double
    var easeFactor: Double
    var nextReviewAt: Date?
    var reviewCount: Int
    var isSeed: Bool

    init(
        id: UUID = UUID(),
        text: String,
        translatedText: String,
        language: String,
        bookTitle: String,
        bookID: UUID? = nil,
        createdAt: Date = Date(),
        author: String = "",
        page: String = "",
        isFavorite: Bool = false,
        notes: String = "",
        intervalDays: Double = 0,
        easeFactor: Double = 2.5,
        nextReviewAt: Date? = nil,
        reviewCount: Int = 0,
        isSeed: Bool = false
    ) {
        self.id = id
        self.text = text
        self.translatedText = translatedText
        self.language = language
        self.bookTitle = bookTitle
        self.bookID = bookID
        self.createdAt = createdAt
        self.author = author
        self.page = page
        self.isFavorite = isFavorite
        self.notes = notes
        self.intervalDays = intervalDays
        self.easeFactor = easeFactor
        self.nextReviewAt = nextReviewAt
        self.reviewCount = reviewCount
        self.isSeed = isSeed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        translatedText = try container.decode(String.self, forKey: .translatedText)
        language = try container.decode(String.self, forKey: .language)
        bookTitle = try container.decode(String.self, forKey: .bookTitle)
        bookID = try container.decodeIfPresent(UUID.self, forKey: .bookID)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        author = try container.decodeIfPresent(String.self, forKey: .author) ?? ""
        page = try container.decodeIfPresent(String.self, forKey: .page) ?? ""
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        intervalDays = try container.decodeIfPresent(Double.self, forKey: .intervalDays) ?? 0
        easeFactor = try container.decodeIfPresent(Double.self, forKey: .easeFactor) ?? 2.5
        nextReviewAt = try container.decodeIfPresent(Date.self, forKey: .nextReviewAt)
        reviewCount = try container.decodeIfPresent(Int.self, forKey: .reviewCount) ?? 0
        isSeed = try container.decodeIfPresent(Bool.self, forKey: .isSeed) ?? false
    }
}

struct MissedWord: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var word: String
    var language: String
    var lastSeenAt: Date
    var count: Int
    var exampleQuoteID: UUID?
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

    static func displayName(for code: String) -> String {
        TargetLanguage(rawValue: code)?.displayName ?? code.uppercased()
    }
}

enum LibraryDestination: String, CaseIterable, Identifiable, Hashable {
    case library
    case desk
    case study

    var id: String { rawValue }

    var title: String {
        switch self {
        case .library: return "Library"
        case .desk: return "Desk"
        case .study: return "Study"
        }
    }

    var symbolName: String {
        switch self {
        case .library: return "books.vertical.fill"
        case .desk: return "doc.text.viewfinder"
        case .study: return "rectangle.on.rectangle.angled"
        }
    }
}

enum QuoteSort: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case book
    case language
    case due

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: return "Newest"
        case .oldest: return "Oldest"
        case .book: return "Book"
        case .language: return "Language"
        case .due: return "Due next"
        }
    }
}

enum ReviewGrade: String {
    case again
    case hard
    case good
    case easy
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
