import SwiftUI
import UIKit

enum QuoteDraft: Identifiable, Equatable {
    case create
    case createForBook(UUID)
    case createFromScan(String)
    case edit(UUID)

    var id: String {
        switch self {
        case .create: return "create"
        case .createForBook(let bookID): return "book-\(bookID.uuidString)"
        case .createFromScan(let text): return "scan-\(text.hashValue)"
        case .edit(let quoteID): return quoteID.uuidString
        }
    }
}

struct DeskWorkspace: View {
    @EnvironmentObject private var store: Store
    @State private var path = NavigationPath()
    @State private var draft: QuoteDraft?
    @State private var showCapture = false
    @State private var query = ""
    @State private var favoritesOnly = false
    @State private var languageFilter: String?
    @State private var sort: QuoteSort = .newest
    @State private var pendingDeleteIDs: [UUID] = []
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        captureCard
                        filterBar
                        quoteBlocks
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 88)
                }
                .clearScrollBackground()

                Menu {
                    Button {
                        draft = .create
                    } label: {
                        Label("Type Quote", systemImage: "pencil")
                    }
                    Button {
                        showCapture = true
                    } label: {
                        Label("Scan Page", systemImage: "doc.text.viewfinder")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 54, height: 54)
                        .background {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color("AppPrimary"), Color("AppAccent")],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .shadow(color: Color("AppPrimary").opacity(0.35), radius: 8, y: 3)
                        }
                }
                .padding(.trailing, 18)
                .padding(.bottom, 18)
            }
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
        .sheet(isPresented: $showCapture) {
            PageCaptureView { text in
                draft = .createFromScan(text)
            }
        }
        .alert("Delete Quote?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                store.delete(ids: pendingDeleteIDs)
                pendingDeleteIDs = []
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteIDs = []
            }
        } message: {
            Text("This quote will leave your shelf and study queue.")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("dataReset"))) { _ in
            path = NavigationPath()
            draft = nil
            query = ""
            favoritesOnly = false
            languageFilter = nil
            sort = .newest
        }
    }

    private var displayed: [Quote] {
        var items = store.quotes
        if favoritesOnly {
            items = items.filter(\.isFavorite)
        }
        if let languageFilter {
            items = items.filter { $0.language == languageFilter }
        }
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !needle.isEmpty {
            items = items.filter { quote in
                quote.text.lowercased().contains(needle)
                    || quote.translatedText.lowercased().contains(needle)
                    || quote.bookTitle.lowercased().contains(needle)
                    || quote.author.lowercased().contains(needle)
            }
        }
        switch sort {
        case .newest:
            return items.sorted { $0.createdAt > $1.createdAt }
        case .oldest:
            return items.sorted { $0.createdAt < $1.createdAt }
        case .book:
            return items.sorted { $0.bookTitle.localizedCaseInsensitiveCompare($1.bookTitle) == .orderedAscending }
        case .language:
            return items.sorted {
                TargetLanguage.displayName(for: $0.language).localizedCaseInsensitiveCompare(
                    TargetLanguage.displayName(for: $1.language)
                ) == .orderedAscending
            }
        case .due:
            return items.sorted {
                ($0.nextReviewAt ?? .distantFuture) < ($1.nextReviewAt ?? .distantFuture)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Desk")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundColor(Color("AppPrimary"))
            Text("Scan a page or craft a bilingual line")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(Color.white.opacity(0.9))
        }
    }

    private var captureCard: some View {
        InkPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(Color("AppPrimary"))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Page Capture")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(Color.primary)
                        Text("Photograph a printed page. On-device OCR drops the text into a new quote.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(Color.primary.opacity(0.7))
                    }
                }
                AmberCTA(title: "Scan Book Page") {
                    showCapture = true
                }
            }
        }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Search lines and titles", text: $query)
                .font(.system(.body, design: .rounded))
                .padding(10)
                .background(Color.white.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    AmberChip(title: "All", isOn: !favoritesOnly && languageFilter == nil) {
                        favoritesOnly = false
                        languageFilter = nil
                    }
                    AmberChip(title: "Favorites", isOn: favoritesOnly) {
                        favoritesOnly.toggle()
                    }
                    ForEach(store.languagesInLibrary()) { language in
                        AmberChip(title: language.displayName, isOn: languageFilter == language.rawValue) {
                            languageFilter = languageFilter == language.rawValue ? nil : language.rawValue
                        }
                    }
                }
            }

            HStack {
                Menu {
                    ForEach(QuoteSort.allCases) { option in
                        Button(option.title) { sort = option }
                    }
                } label: {
                    Text("Sort: \(sort.title)")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundColor(Color("AppAccent"))
                }
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var quoteBlocks: some View {
        if store.quotes.isEmpty {
            InkPanel {
                VStack(spacing: 16) {
                    EmptyQuotesPanel()
                    AmberCTA(title: "Type First Quote") { draft = .create }
                }
                .frame(minHeight: 220)
            }
        } else if displayed.isEmpty {
            InkPanel {
                EmptyQuotesPanel(
                    title: "No Matches",
                    detail: "Clear a filter or try another word."
                )
                .frame(minHeight: 180)
            }
        } else {
            ForEach(displayed) { quote in
                Button {
                    path.append(quote.id)
                } label: {
                    InkPanel {
                        QuoteLedgerRow(quote: quote)
                    }
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        store.toggleFavorite(quote.id)
                    } label: {
                        Label(quote.isFavorite ? "Unfavorite" : "Favorite", systemImage: "bookmark")
                    }
                    Button(role: .destructive) {
                        pendingDeleteIDs = [quote.id]
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }
}

struct QuoteLedgerRow: View {
    let quote: Quote

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color("AppPrimary"))
                .frame(width: 4, height: 42)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(quote.bookTitle)
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(Color.primary)
                        .lineLimit(1)
                    if quote.isFavorite {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color("AppAccent"))
                    }
                    if quote.isSeed {
                        Text("SEED")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(Color("AppPrimary"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color("AppAccent").opacity(0.25))
                            .clipShape(Capsule())
                    }
                }
                if !quote.author.isEmpty || !quote.page.isEmpty {
                    Text(attribution(quote))
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(Color.primary.opacity(0.6))
                        .lineLimit(1)
                }
                Text(quote.text)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(Color.primary.opacity(0.78))
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(TargetLanguage.displayName(for: quote.language))
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundColor(Color("AppPrimary"))
                    if let due = quote.nextReviewAt {
                        Text("Due \(due.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(Color.primary.opacity(0.55))
                    }
                }
            }
        }
    }

    private func attribution(_ quote: Quote) -> String {
        var parts: [String] = []
        if !quote.author.isEmpty { parts.append(quote.author) }
        if !quote.page.isEmpty { parts.append("p. \(quote.page)") }
        return parts.joined(separator: " · ")
    }
}

struct QuoteDetailView: View {
    let quoteID: UUID
    var onEdit: () -> Void
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var copiedMessage = ""
    @State private var showShare = false

    var body: some View {
        Group {
            if let quote = store.quote(id: quoteID) {
                detail(quote)
            } else {
                EmptyQuotesPanel(title: "Quote Unavailable", detail: "This entry is no longer on your desk.")
                    .padding(16)
            }
        }
        .libraryBackdrop()
        .onAppear { store.markViewed(quoteID) }
        .alert("Delete Quote?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                store.delete(ids: [quoteID])
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This quote will leave your shelf and study queue.")
        }
        .sheet(isPresented: $showShare) {
            if let quote = store.quote(id: quoteID) {
                ShareQuoteCard(quote: quote)
            }
        }
    }

    private func detail(_ quote: Quote) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { dismiss() } label: {
                    Label("Back", systemImage: "chevron.left")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundColor(Color("AppAccent"))
                }
                Spacer()
                Button { store.toggleFavorite(quoteID) } label: {
                    Image(systemName: (store.quote(id: quoteID)?.isFavorite == true) ? "bookmark.fill" : "bookmark")
                        .foregroundColor(Color("AppAccent"))
                }
                Button("Edit", action: onEdit)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundColor(Color("AppAccent"))
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Text(quote.bookTitle)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundColor(Color("AppPrimary"))
                .padding(.horizontal, 16)

            ScrollView {
                InkPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Original")
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundColor(Color("AppPrimary"))
                        Text(quote.text)
                            .font(.system(.title3, design: .rounded))
                            .foregroundColor(Color.primary)
                        LedgerDivider()
                        Text("Translation")
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundColor(Color("AppPrimary"))
                        Text(quote.translatedText)
                            .font(.system(.title3, design: .rounded))
                            .foregroundColor(Color.primary)
                        if !quote.notes.isEmpty {
                            LedgerDivider()
                            Text("Notes")
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundColor(Color("AppPrimary"))
                            Text(quote.notes)
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(Color.primary.opacity(0.8))
                        }
                        HStack(spacing: 8) {
                            copyButton("Original") { copy(quote.text, label: "Copied original.") }
                            copyButton("Translation") { copy(quote.translatedText, label: "Copied translation.") }
                            Button("Share Card") { showShare = true }
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .foregroundColor(Color("AppPrimary"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color("AppPrimary").opacity(0.45), lineWidth: 0.8)
                                )
                        }
                        FieldHint(text: copiedMessage, isError: false)
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Text("Delete Quote")
                                .font(.system(.headline, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .clearScrollBackground()
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func copyButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundColor(Color("AppPrimary"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color("AppPrimary").opacity(0.45), lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
    }

    private func copy(_ value: String, label: String) {
        UIPasteboard.general.string = value
        copiedMessage = label
    }
}

struct ShareQuoteCard: View {
    let quote: Quote
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button("Close") { dismiss() }
                    .foregroundColor(Color("AppAccent"))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            InkPanel {
                VStack(alignment: .leading, spacing: 12) {
                    Text(quote.bookTitle)
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundColor(Color("AppPrimary"))
                    Text(quote.text)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                    Text(quote.translatedText)
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(Color.primary.opacity(0.75))
                    if !quote.author.isEmpty {
                        Text("— \(quote.author)")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(Color.primary.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 16)

            ShareLink(item: "\(quote.text)\n\n\(quote.translatedText)\n— \(quote.author.isEmpty ? quote.bookTitle : quote.author)") {
                Text("Share Text")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color("AppPrimary")))
            }
            .padding(.horizontal, 16)
            Spacer()
        }
        .libraryBackdrop()
    }
}

struct QuoteEditorView: View {
    let draft: QuoteDraft
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var bookTitle = ""
    @State private var author = ""
    @State private var page = ""
    @State private var notes = ""
    @State private var text = ""
    @State private var translatedDraft = ""
    @State private var languageCode = TargetLanguage.spanish.rawValue
    @State private var outcome: TranslationOutcome?
    @State private var showTitleError = false
    @State private var showTextError = false
    @State private var showTranslationError = false
    @State private var showLanguageError = false
    @State private var existingID: UUID?
    @State private var createdAt = Date()
    @State private var isFavorite = false
    @State private var lockedBookID: UUID?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button("Close") { dismiss() }
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundColor(Color("AppAccent"))
                    Spacer()
                    Text(existingID == nil ? "New Quote" : "Edit Quote")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(Color("AppPrimary"))
                    Spacer()
                    Color.clear.frame(width: 48, height: 1)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                ScrollView {
                    InkPanel {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Book Title")
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundColor(Color("AppPrimary"))
                            EditorField(placeholder: "Title of the book", text: $bookTitle)
                                .disabled(lockedBookID != nil)
                            FieldHint(text: showTitleError ? "Add a book title." : "")

                            Text("Author")
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundColor(Color("AppPrimary"))
                            EditorField(placeholder: "Optional", text: $author)

                            Text("Page")
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundColor(Color("AppPrimary"))
                            EditorField(placeholder: "Optional", text: $page)

                            Text("Original Quote")
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundColor(Color("AppPrimary"))
                            TextEditor(text: $text)
                                .font(.system(.body, design: .rounded))
                                .frame(minHeight: 120)
                                .scrollContentBackground(.hidden)
                                .padding(6)
                                .background(Color("AppSurface").opacity(0.18))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            FieldHint(text: showTextError ? "Enter the original quote." : "")

                            Text("Language")
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundColor(Color("AppPrimary"))
                            LanguageChipRow(languages: editorLanguages, selectedCode: $languageCode)
                            FieldHint(text: showLanguageError ? "Choose a language." : "")

                            Text("Translation")
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundColor(Color("AppPrimary"))
                            TextEditor(text: $translatedDraft)
                                .font(.system(.body, design: .rounded))
                                .frame(minHeight: 120)
                                .scrollContentBackground(.hidden)
                                .padding(6)
                                .background(Color("AppSurface").opacity(0.18))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            FieldHint(
                                text: showTranslationError ? "Enter the translation." : "Write the line in the chosen language.",
                                isError: showTranslationError
                            )

                            Text("Reader Notes")
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundColor(Color("AppPrimary"))
                            EditorField(placeholder: "Optional context", text: $notes)

                            AmberCTA(title: "Fill from Dictionary", isEnabled: !trimmedText.isEmpty) {
                                runTranslation()
                            }

                            if let outcome {
                                coverageBlock(outcome)
                            }

                            AmberCTA(title: "Save Quote", isEnabled: canSave) {
                                save()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
                .clearScrollBackground()
                .scrollDismissesKeyboard(.immediately)
            }
            .libraryBackdrop()
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear { hydrate() }
    }

    private var editorLanguages: [TargetLanguage] {
        var list = store.availableLanguages()
        if let current = TargetLanguage.resolved(languageCode), list.contains(current) == false {
            list.insert(current, at: 0)
        }
        return list
    }

    private var trimmedTitle: String {
        bookTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedTranslation: String {
        translatedDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedTitle.isEmpty
            && !trimmedText.isEmpty
            && !trimmedTranslation.isEmpty
            && TargetLanguage.resolved(languageCode) != nil
    }

    private func coverageBlock(_ outcome: TranslationOutcome) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dictionary coverage \(outcome.coveragePercent)%")
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundColor(Color("AppPrimary"))
            if outcome.coverage > 0 {
                Text("A draft was placed in the translation field. Edit before saving.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(Color.primary.opacity(0.65))
            } else {
                Text("Write the translation manually, then save.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(Color.primary.opacity(0.65))
            }
            if !outcome.unknownWords.isEmpty {
                Text("Unknown words: \(outcome.unknownWords.joined(separator: ", "))")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundColor(Color("AppPrimary"))
            }
        }
    }

    private func runTranslation() {
        showTitleError = trimmedTitle.isEmpty
        showTextError = trimmedText.isEmpty
        showLanguageError = TargetLanguage.resolved(languageCode) == nil
        guard !trimmedText.isEmpty, TargetLanguage.resolved(languageCode) != nil else { return }
        let result = Translator.translate(trimmedText, into: languageCode)
        outcome = result
        if result.coverage > 0, !result.translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            translatedDraft = result.translatedText
            showTranslationError = false
        }
        store.recordUnknownWords(result.unknownWords, language: languageCode, exampleQuoteID: existingID)
    }

    private func save() {
        showTitleError = trimmedTitle.isEmpty
        showTextError = trimmedText.isEmpty
        showTranslationError = trimmedTranslation.isEmpty
        showLanguageError = TargetLanguage.resolved(languageCode) == nil
        guard canSave else { return }
        let quote = Quote(
            id: existingID ?? UUID(),
            text: trimmedText,
            translatedText: trimmedTranslation,
            language: languageCode,
            bookTitle: trimmedTitle,
            bookID: lockedBookID,
            createdAt: createdAt,
            author: author.trimmingCharacters(in: .whitespacesAndNewlines),
            page: page.trimmingCharacters(in: .whitespacesAndNewlines),
            isFavorite: isFavorite,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            nextReviewAt: Date()
        )
        store.upsert(quote)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    private func hydrate() {
        let languages = store.availableLanguages()
        if let first = languages.first {
            languageCode = first.rawValue
        }
        switch draft {
        case .create:
            existingID = nil
            createdAt = Date()
            isFavorite = false
        case .createForBook(let bookID):
            existingID = nil
            lockedBookID = bookID
            if let book = store.book(id: bookID) {
                bookTitle = book.title
                author = book.author
            }
        case .createFromScan(let scanned):
            existingID = nil
            text = scanned
        case .edit(let quoteID):
            guard let quote = store.quote(id: quoteID) else { return }
            existingID = quote.id
            bookTitle = quote.bookTitle
            author = quote.author
            page = quote.page
            notes = quote.notes
            text = quote.text
            translatedDraft = quote.translatedText
            languageCode = quote.language
            createdAt = quote.createdAt
            isFavorite = quote.isFavorite
            lockedBookID = quote.bookID
        }
    }
}
