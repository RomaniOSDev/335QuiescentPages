import SwiftUI
import UIKit

enum QuoteDraft: Identifiable, Equatable {
    case create
    case edit(UUID)

    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let quoteID): return quoteID.uuidString
        }
    }
}

struct QuoteWorkspace: View {
    @EnvironmentObject private var store: Store
    @State private var path = NavigationPath()
    @State private var editMode: EditMode = .inactive
    @State private var draft: QuoteDraft?
    @State private var pendingDeleteIDs: [UUID] = []
    @State private var showDeleteConfirm = false
    @State private var query = ""
    @State private var favoritesOnly = false
    @State private var languageFilter: String?
    @State private var bookFilter: String?
    @State private var sort: QuoteSort = .newest

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationStack(path: $path) {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    LibraryBanner(imageName: LibraryDestination.quotes.bannerName)
                    ParchmentStage(fillsAvailable: true) {
                        quoteList
                    }
                    .padding(.bottom, 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(DisableNavBarHits())
                .navigationDestination(for: UUID.self) { quoteID in
                    QuoteDetailView(quoteID: quoteID, onEdit: { draft = .edit(quoteID) })
                }
                .toolbar(.hidden, for: .navigationBar)
            }
            if path.isEmpty {
                NewQuoteButton { draft = .create }
                    .padding(.top, 12)
                    .padding(.trailing, 16)
            }
        }
        .environment(\.editMode, $editMode)
        .sheet(item: $draft) { item in
            QuoteEditorView(draft: item)
                .environmentObject(store)
        }
        .alert("Delete Quote?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                store.delete(ids: pendingDeleteIDs)
                pendingDeleteIDs = []
                editMode = .inactive
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteIDs = []
            }
        } message: {
            Text("This quote will be removed from your collection and history.")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("dataReset"))) { _ in
            path = NavigationPath()
            draft = nil
            editMode = .inactive
            query = ""
            favoritesOnly = false
            languageFilter = nil
            bookFilter = nil
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
        if let bookFilter {
            items = items.filter { $0.bookTitle == bookFilter }
        }
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !needle.isEmpty {
            items = items.filter { quote in
                quote.text.lowercased().contains(needle)
                    || quote.translatedText.lowercased().contains(needle)
                    || quote.bookTitle.lowercased().contains(needle)
                    || quote.author.lowercased().contains(needle)
                    || TargetLanguage.displayName(for: quote.language).lowercased().contains(needle)
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
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Quotes")
                    .font(.system(.largeTitle, design: .serif).weight(.semibold))
                    .foregroundColor(Color("AppPrimary"))
                Text("Lines kept between covers")
                    .font(.system(.subheadline, design: .serif))
                    .foregroundColor(Color.white.opacity(0.9))
            }
            Spacer()
            if !displayed.isEmpty {
                Button(editMode.isEditing ? "Done" : "Edit") {
                    withAnimation {
                        editMode = editMode.isEditing ? .inactive : .active
                    }
                }
                .font(.system(.body, design: .serif).weight(.semibold))
                .foregroundColor(Color("AppAccent"))
            }
            Color.clear
                .frame(width: 44, height: 44)
        }
        .zIndex(2)
    }

    @ViewBuilder
    private var quoteList: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let daily = store.quoteOfTheDay() {
                Button {
                    path.append(daily.id)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Quote of the Day")
                            .font(.system(.caption, design: .serif).weight(.semibold))
                            .foregroundColor(Color("AppPrimary"))
                        Text(daily.text)
                            .font(.system(.body, design: .serif))
                            .foregroundColor(Color.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color("AppAccent").opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if !store.sortedQuotes.isEmpty {
                filterBar
            }

            if store.sortedQuotes.isEmpty {
                VStack(spacing: 18) {
                    EmptyQuotesPanel()
                    AmberCTA(title: "Add Quote") {
                        draft = .create
                    }
                }
                .frame(minHeight: 240)
            } else if displayed.isEmpty {
                EmptyQuotesPanel(
                    title: "No Matching Quotes",
                    detail: "Clear a filter or try another word from the line or the book."
                )
                .frame(minHeight: 200)
            } else {
                List {
                    ForEach(displayed) { quote in
                        Button {
                            path.append(quote.id)
                        } label: {
                            QuoteLedgerRow(quote: quote)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                store.toggleFavorite(quote.id)
                            } label: {
                                Label(quote.isFavorite ? "Unfavorite" : "Favorite", systemImage: quote.isFavorite ? "bookmark.slash" : "bookmark.fill")
                            }
                            .tint(Color("AppPrimary"))
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDeleteIDs = [quote.id]
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete { indexSet in
                        pendingDeleteIDs = indexSet.compactMap { displayed[safe: $0]?.id }
                        showDeleteConfirm = true
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.immediately)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Search titles and lines", text: $query)
                .font(.system(.body, design: .serif))
                .padding(10)
                .background(Color("AppSurface").opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .submitLabel(.search)

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
                    Button("All Books") { bookFilter = nil }
                    ForEach(store.distinctBookTitles(), id: \.self) { title in
                        Button(title) { bookFilter = title }
                    }
                } label: {
                    Text(bookFilter ?? "Book")
                        .font(.system(.caption, design: .serif).weight(.semibold))
                        .foregroundColor(Color("AppAccent"))
                }
                Spacer()
                Menu {
                    ForEach(QuoteSort.allCases) { option in
                        Button(option.title) { sort = option }
                    }
                } label: {
                    Text("Sort: \(sort.title)")
                        .font(.system(.caption, design: .serif).weight(.semibold))
                        .foregroundColor(Color("AppAccent"))
                }
            }
        }
    }
}

struct QuoteLedgerRow: View {
    let quote: Quote

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            BookmarkShape()
                .fill(Color("AppPrimary"))
                .frame(width: 12, height: 28)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(quote.bookTitle)
                        .font(.system(.headline, design: .serif))
                        .foregroundColor(Color.primary)
                        .lineLimit(1)
                    if quote.isFavorite {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color("AppAccent"))
                    }
                }
                if !quote.author.isEmpty || !quote.page.isEmpty {
                    Text(attribution(quote))
                        .font(.system(.caption, design: .serif))
                        .foregroundColor(Color.primary.opacity(0.6))
                        .lineLimit(1)
                }
                Text(quote.text)
                    .font(.system(.body, design: .serif))
                    .foregroundColor(Color.primary.opacity(0.78))
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(TargetLanguage.displayName(for: quote.language))
                        .font(.system(.caption, design: .serif).weight(.semibold))
                        .foregroundColor(Color("AppPrimary"))
                    Text(quote.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(.caption, design: .serif))
                        .foregroundColor(Color.primary.opacity(0.55))
                }
                LedgerDivider()
            }
        }
    }

    private func attribution(_ quote: Quote) -> String {
        var parts: [String] = []
        if !quote.author.isEmpty {
            parts.append(quote.author)
        }
        if !quote.page.isEmpty {
            parts.append("p. \(quote.page)")
        }
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

    var body: some View {
        Group {
            if let quote = store.quote(id: quoteID) {
                detail(quote)
            } else {
                EmptyQuotesPanel(title: "Quote Unavailable", detail: "This entry is no longer in your collection.")
                    .padding(16)
            }
        }
        .libraryBackdrop()
        .onAppear {
            store.markViewed(quoteID)
        }
        .alert("Delete Quote?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                store.delete(ids: [quoteID])
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This quote will be removed from your collection and history.")
        }
    }

    private func detail(_ quote: Quote) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .font(.system(.body, design: .serif).weight(.semibold))
                        .foregroundColor(Color("AppAccent"))
                }
                Spacer()
                Button {
                    store.toggleFavorite(quoteID)
                } label: {
                    Image(systemName: (store.quote(id: quoteID)?.isFavorite == true) ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color("AppAccent"))
                }
                .accessibilityLabel("Favorite")
                Button("Edit") {
                    onEdit()
                }
                .font(.system(.body, design: .serif).weight(.semibold))
                .foregroundColor(Color("AppAccent"))
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Text(quote.bookTitle)
                .font(.system(.largeTitle, design: .serif).weight(.semibold))
                .foregroundColor(Color("AppPrimary"))
                .padding(.horizontal, 16)
            if !quote.author.isEmpty || !quote.page.isEmpty {
                Text(detailAttribution(quote))
                    .font(.system(.subheadline, design: .serif))
                    .foregroundColor(Color.white.opacity(0.88))
                    .padding(.horizontal, 16)
            }

            LibraryBanner(imageName: "BannerPen")
                .padding(.horizontal, 16)

            ScrollView {
                ParchmentStage {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Original")
                            .font(.system(.caption, design: .serif).weight(.semibold))
                            .foregroundColor(Color("AppPrimary"))
                        Text(quote.text)
                            .font(.system(.title3, design: .serif))
                            .foregroundColor(Color.primary)
                        LedgerDivider()
                        Text("Translation")
                            .font(.system(.caption, design: .serif).weight(.semibold))
                            .foregroundColor(Color("AppPrimary"))
                        Text(quote.translatedText)
                            .font(.system(.title3, design: .serif))
                            .foregroundColor(Color.primary)
                        HStack(spacing: 8) {
                            copyButton("Original") { copy(quote.text, label: "Copied original.") }
                            copyButton("Translation") { copy(quote.translatedText, label: "Copied translation.") }
                            copyButton("Both") {
                                copy("\(quote.text)\n\n\(quote.translatedText)", label: "Copied both.")
                            }
                        }
                        FieldHint(text: copiedMessage, isError: false)
                        LedgerDivider()
                        HStack {
                            Text(TargetLanguage.displayName(for: quote.language))
                                .font(.system(.subheadline, design: .serif).weight(.semibold))
                                .foregroundColor(Color("AppPrimary"))
                            Spacer()
                            Text(quote.createdAt.formatted(date: .long, time: .shortened))
                                .font(.system(.caption, design: .serif))
                                .foregroundColor(Color.primary.opacity(0.6))
                        }
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Text("Delete Quote")
                                .font(.system(.headline, design: .serif))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func detailAttribution(_ quote: Quote) -> String {
        var parts: [String] = []
        if !quote.author.isEmpty {
            parts.append(quote.author)
        }
        if !quote.page.isEmpty {
            parts.append("p. \(quote.page)")
        }
        return parts.joined(separator: " · ")
    }

    private func copyButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.caption, design: .serif).weight(.semibold))
                .foregroundColor(Color("AppPrimary"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
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

struct QuoteEditorView: View {
    let draft: QuoteDraft
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var bookTitle = ""
    @State private var author = ""
    @State private var page = ""
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

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button("Close") { dismiss() }
                        .font(.system(.body, design: .serif).weight(.semibold))
                        .foregroundColor(Color("AppAccent"))
                    Spacer()
                    Text(existingID == nil ? "New Quote" : "Edit Quote")
                        .font(.system(.headline, design: .serif))
                        .foregroundColor(Color("AppPrimary"))
                    Spacer()
                    Color.clear.frame(width: 48, height: 1)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                LibraryBanner(imageName: "BannerPen")
                    .padding(.horizontal, 16)

                ScrollView {
                    ParchmentStage {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Book Title")
                                .font(.system(.caption, design: .serif).weight(.semibold))
                                .foregroundColor(Color("AppPrimary"))
                            EditorField(placeholder: "Title of the book", text: $bookTitle)
                            FieldHint(text: showTitleError ? "Add a book title." : "")

                            Text("Author")
                                .font(.system(.caption, design: .serif).weight(.semibold))
                                .foregroundColor(Color("AppPrimary"))
                            EditorField(placeholder: "Optional", text: $author)

                            Text("Page")
                                .font(.system(.caption, design: .serif).weight(.semibold))
                                .foregroundColor(Color("AppPrimary"))
                            EditorField(placeholder: "Optional", text: $page)

                            Text("Original Quote")
                                .font(.system(.caption, design: .serif).weight(.semibold))
                                .foregroundColor(Color("AppPrimary"))
                            TextEditor(text: $text)
                                .font(.system(.body, design: .serif))
                                .frame(minHeight: 120)
                                .scrollContentBackground(.hidden)
                                .padding(6)
                                .background(Color("AppSurface").opacity(0.18))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            FieldHint(text: showTextError ? "Enter the original quote." : "")

                            Text("Language")
                                .font(.system(.caption, design: .serif).weight(.semibold))
                                .foregroundColor(Color("AppPrimary"))
                            LanguageChipRow(languages: editorLanguages, selectedCode: $languageCode)
                            FieldHint(text: showLanguageError ? "Choose a language." : "")

                            Text("Translation")
                                .font(.system(.caption, design: .serif).weight(.semibold))
                                .foregroundColor(Color("AppPrimary"))
                            TextEditor(text: $translatedDraft)
                                .font(.system(.body, design: .serif))
                                .frame(minHeight: 120)
                                .scrollContentBackground(.hidden)
                                .padding(6)
                                .background(Color("AppSurface").opacity(0.18))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            FieldHint(
                                text: showTranslationError ? "Enter the translation." : "Write the line in the chosen language.",
                                isError: showTranslationError
                            )

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
                .scrollDismissesKeyboard(.immediately)
            }
            .libraryBackdrop()
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            hydrate()
        }
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
                .font(.system(.caption, design: .serif).weight(.semibold))
                .foregroundColor(Color("AppPrimary"))
            if outcome.coverage > 0 {
                Text("A draft was placed in the translation field. Edit it before saving if the desk missed the line.")
                    .font(.system(.caption, design: .serif))
                    .foregroundColor(Color.primary.opacity(0.65))
            } else {
                Text("The desk dictionary could not render this line. Write the translation in the field above, then save.")
                    .font(.system(.caption, design: .serif))
                    .foregroundColor(Color.primary.opacity(0.65))
            }
            if !outcome.unknownWords.isEmpty {
                Text("Unknown words: \(outcome.unknownWords.joined(separator: ", "))")
                    .font(.system(.caption, design: .serif).weight(.semibold))
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
        store.recordUnknownWords(result.unknownWords, language: languageCode)
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
            createdAt: createdAt,
            author: author.trimmingCharacters(in: .whitespacesAndNewlines),
            page: page.trimmingCharacters(in: .whitespacesAndNewlines),
            isFavorite: isFavorite
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
        case .edit(let quoteID):
            guard let quote = store.quote(id: quoteID) else { return }
            existingID = quote.id
            bookTitle = quote.bookTitle
            author = quote.author
            page = quote.page
            text = quote.text
            translatedDraft = quote.translatedText
            languageCode = quote.language
            createdAt = quote.createdAt
            isFavorite = quote.isFavorite
        }
    }
}


