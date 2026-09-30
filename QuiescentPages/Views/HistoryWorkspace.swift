import Charts
import SwiftUI

struct LibraryWorkspace: View {
    @EnvironmentObject private var store: Store
    @State private var path = NavigationPath()
    @State private var showBookEditor = false
    @State private var editingBook: Book?
    @State private var draft: QuoteDraft?
    @State private var query = ""

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.clear
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        insightStrip
                        if let daily = store.quoteOfTheDay() {
                            dailyBlock(daily)
                        }
                        shelvesHeader
                        shelvesList
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .clearScrollBackground()
            }
            .background(DisableNavBarHits())
            .navigationDestination(for: UUID.self) { id in
                if store.book(id: id) != nil {
                    BookDetailView(bookID: id)
                } else {
                    QuoteDetailView(quoteID: id, onEdit: { draft = .edit(id) })
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $draft) { item in
            QuoteEditorView(draft: item)
                .environmentObject(store)
        }
        .sheet(isPresented: $showBookEditor) {
            BookEditorSheet(book: editingBook)
                .environmentObject(store)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("dataReset"))) { _ in
            path = NavigationPath()
            draft = nil
            query = ""
        }
    }

    private var filteredBooks: [Book] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return store.sortedBooks }
        return store.sortedBooks.filter {
            $0.title.lowercased().contains(needle) || $0.author.lowercased().contains(needle)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Library")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundColor(Color("AppPrimary"))
            Text("Shelves, streaks, and the line for today")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(Color.white.opacity(0.9))
        }
    }

    private var insightStrip: some View {
        HStack(spacing: 10) {
            StatPill(title: "Quotes", value: "\(store.quotes.count)")
            StatPill(title: "Books", value: "\(store.books.count)")
            StatPill(title: "Streak", value: "\(store.currentStreak())d")
            StatPill(title: "Due", value: "\(store.dueQuotes.count)")
        }
    }

    private func dailyBlock(_ quote: Quote) -> some View {
        InkPanel {
            VStack(alignment: .leading, spacing: 10) {
                Text("Line of the Day")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundColor(Color("AppPrimary"))
                Button {
                    path.append(quote.id)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(quote.text)
                            .font(.system(.body, design: .rounded).weight(.medium))
                            .foregroundColor(Color.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                        Text(quote.bookTitle)
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundColor(Color("AppPrimary"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                if !store.dayInsights(lastDays: 7).allSatisfy({ $0.count == 0 }) {
                    Chart(store.dayInsights(lastDays: 7)) { item in
                        BarMark(
                            x: .value("Day", item.day, unit: .day),
                            y: .value("Count", item.count)
                        )
                        .foregroundStyle(Color("AppPrimary"))
                    }
                    .frame(height: 88)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.weekday(.narrow))
                        }
                    }
                    .chartYAxis(.hidden)
                }
            }
        }
    }

    private var shelvesHeader: some View {
        HStack {
            Text("Shelves")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundColor(Color.white)
            Spacer()
            Button("Add Book") {
                editingBook = nil
                showBookEditor = true
            }
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundColor(Color("AppAccent"))
        }
    }

    private var shelvesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Search shelves", text: $query)
                .font(.system(.body, design: .rounded))
                .padding(12)
                .background(Color.white.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if filteredBooks.isEmpty {
                InkPanel {
                    EmptyQuotesPanel(
                        title: "Empty Shelves",
                        detail: "Add a book or scan a page — seed classics appear after setup."
                    )
                    .frame(minHeight: 180)
                }
            } else {
                ForEach(filteredBooks) { book in
                    Button {
                        path.append(book.id)
                    } label: {
                        InkPanel {
                            HStack(alignment: .top, spacing: 12) {
                                ShelfSpine(tone: book.shelfTone)
                                    .frame(height: 64)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(book.title)
                                        .font(.system(.headline, design: .rounded))
                                        .foregroundColor(Color.primary)
                                        .multilineTextAlignment(.leading)
                                    if !book.author.isEmpty {
                                        Text(book.author)
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundColor(Color.primary.opacity(0.6))
                                    }
                                    Text("\(store.quotes(forBookID: book.id).count) lines")
                                        .font(.system(.caption, design: .rounded).weight(.semibold))
                                        .foregroundColor(Color("AppPrimary"))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Color("AppPrimary").opacity(0.5))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct BookDetailView: View {
    let bookID: UUID
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: QuoteDraft?
    @State private var showEditor = false
    @State private var notesDraft = ""

    var body: some View {
        Group {
            if let book = store.book(id: bookID) {
                content(book)
            } else {
                EmptyQuotesPanel(title: "Book Missing", detail: "This shelf entry is gone.")
                    .padding(16)
            }
        }
        .libraryBackdrop()
        .sheet(item: $draft) { item in
            QuoteEditorView(draft: item)
                .environmentObject(store)
        }
        .sheet(isPresented: $showEditor) {
            if let book = store.book(id: bookID) {
                BookEditorSheet(book: book)
                    .environmentObject(store)
            }
        }
    }

    private func content(_ book: Book) -> some View {
        let lines = store.quotes(forBookID: book.id)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundColor(Color("AppAccent"))
                }
                Spacer()
                Button("Edit") { showEditor = true }
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundColor(Color("AppAccent"))
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            HStack(alignment: .top, spacing: 12) {
                ShelfSpine(tone: book.shelfTone)
                    .frame(height: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundColor(Color("AppPrimary"))
                    if !book.author.isEmpty {
                        Text(book.author)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(Color.white.opacity(0.9))
                    }
                }
            }
            .padding(.horizontal, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    InkPanel {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Shelf Notes")
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundColor(Color("AppPrimary"))
                            Text(book.notes.isEmpty ? "No notes yet. Add context for this volume." : book.notes)
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(Color.primary.opacity(0.8))
                            AmberCTA(title: "Add Quote to This Book") {
                                draft = .createForBook(bookID)
                            }
                        }
                    }

                    Text("Lines")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundColor(Color.white)

                    if lines.isEmpty {
                        InkPanel {
                            EmptyQuotesPanel(title: "No Lines", detail: "Scan a page or type a quote into this book.")
                                .frame(minHeight: 160)
                        }
                    } else {
                        ForEach(lines) { quote in
                            NavigationLink(value: quote.id) {
                                QuoteLedgerRow(quote: quote)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .clearScrollBackground()
        }
        .onAppear { notesDraft = book.notes }
    }
}

struct BookEditorSheet: View {
    let book: Book?
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var author = ""
    @State private var notes = ""
    @State private var tone = 0
    @State private var hint = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button("Close") { dismiss() }
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundColor(Color("AppAccent"))
                    Spacer()
                    Text(book == nil ? "New Book" : "Edit Book")
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
                            Text("Title")
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundColor(Color("AppPrimary"))
                            EditorField(placeholder: "Book title", text: $title)
                            FieldHint(text: hint)

                            Text("Author")
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundColor(Color("AppPrimary"))
                            EditorField(placeholder: "Optional", text: $author)

                            Text("Notes")
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundColor(Color("AppPrimary"))
                            TextEditor(text: $notes)
                                .font(.system(.body, design: .rounded))
                                .frame(minHeight: 100)
                                .scrollContentBackground(.hidden)
                                .padding(6)
                                .background(Color("AppSurface").opacity(0.18))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            Text("Spine tone")
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundColor(Color("AppPrimary"))
                            HStack(spacing: 10) {
                                ForEach(0..<4, id: \.self) { index in
                                    Button {
                                        tone = index
                                    } label: {
                                        ShelfSpine(tone: index)
                                            .frame(height: 36)
                                            .opacity(tone == index ? 1 : 0.45)
                                            .overlay {
                                                if tone == index {
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .stroke(Color("AppPrimary"), lineWidth: 2)
                                                }
                                            }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            AmberCTA(title: "Save Book") {
                                let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else {
                                    hint = "Add a title."
                                    return
                                }
                                let saved = Book(
                                    id: book?.id ?? UUID(),
                                    title: trimmed,
                                    author: author.trimmingCharacters(in: .whitespacesAndNewlines),
                                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                                    createdAt: book?.createdAt ?? Date(),
                                    shelfTone: tone
                                )
                                store.upsertBook(saved)
                                dismiss()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
                .clearScrollBackground()
            }
            .libraryBackdrop()
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            title = book?.title ?? ""
            author = book?.author ?? ""
            notes = book?.notes ?? ""
            tone = book?.shelfTone ?? 0
        }
    }
}
