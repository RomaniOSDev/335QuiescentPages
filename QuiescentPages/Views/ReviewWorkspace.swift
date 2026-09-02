import SwiftUI
import UIKit

struct ReviewWorkspace: View {
    @EnvironmentObject private var store: Store
    @State private var path = NavigationPath()
    @State private var draft: QuoteDraft?
    @State private var showCards = false
    @State private var cardsFavoritesOnly = false
    @State private var sessionDeck: [Quote] = []
    @State private var glossaryLanguage: String?
    @State private var copiedWord = ""

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 12) {
                header
                LibraryBanner(imageName: LibraryDestination.study.bannerName)
                ScrollView {
                    ParchmentStage {
                        studyBody
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
        .sheet(isPresented: $showCards) {
            FlashcardSessionView(quotes: sessionDeck)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("dataReset"))) { _ in
            path = NavigationPath()
            draft = nil
            cardsFavoritesOnly = false
            glossaryLanguage = nil
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Study")
                .font(.system(.largeTitle, design: .serif).weight(.semibold))
                .foregroundColor(Color("AppPrimary"))
            Text("A line for today, then the cards")
                .font(.system(.subheadline, design: .serif))
                .foregroundColor(Color.white.opacity(0.9))
        }
    }

    @ViewBuilder
    private var studyBody: some View {
        if store.sortedQuotes.isEmpty {
            EmptyQuotesPanel(
                title: "Nothing to Study Yet",
                detail: "Save a translation and this desk will keep a daily line, cards, and missed words."
            )
            .frame(minHeight: 260)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                dailyCard
                LedgerDivider()
                cardsSection
                LedgerDivider()
                glossarySection
            }
        }
    }

    @ViewBuilder
    private var dailyCard: some View {
        if let daily = store.quoteOfTheDay() {
            VStack(alignment: .leading, spacing: 8) {
                Text("Quote of the Day")
                    .font(.system(.headline, design: .serif))
                    .foregroundColor(Color("AppPrimary"))
                Button {
                    path.append(daily.id)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(daily.text)
                            .font(.system(.title3, design: .serif))
                            .foregroundColor(Color.primary)
                            .multilineTextAlignment(.leading)
                        Text(daily.translatedText)
                            .font(.system(.body, design: .serif))
                            .foregroundColor(Color.primary.opacity(0.75))
                            .multilineTextAlignment(.leading)
                        HStack {
                            Text(daily.bookTitle)
                                .font(.system(.caption, design: .serif).weight(.semibold))
                                .foregroundColor(Color("AppPrimary"))
                            if !daily.author.isEmpty {
                                Text(daily.author)
                                    .font(.system(.caption, design: .serif))
                                    .foregroundColor(Color.primary.opacity(0.6))
                            }
                            Spacer()
                            Text(TargetLanguage.displayName(for: daily.language))
                                .font(.system(.caption, design: .serif))
                                .foregroundColor(Color.primary.opacity(0.55))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color("AppAccent").opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var cardsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Review Cards")
                .font(.system(.headline, design: .serif))
                .foregroundColor(Color("AppPrimary"))
            Text("See the original, then tap to uncover the translation.")
                .font(.system(.subheadline, design: .serif))
                .foregroundColor(Color.primary.opacity(0.7))
            AmberChip(title: cardsFavoritesOnly ? "Favorites only" : "Whole shelf", isOn: cardsFavoritesOnly) {
                cardsFavoritesOnly.toggle()
            }
            AmberCTA(title: "Start Cards", isEnabled: !availableCards.isEmpty) {
                sessionDeck = availableCards.shuffled()
                showCards = true
            }
            if cardsFavoritesOnly && availableCards.isEmpty {
                FieldHint(text: "Mark a favorite before starting this deck.", isError: true)
            }
        }
    }

    private var availableCards: [Quote] {
        cardsFavoritesOnly ? store.quotes.filter(\.isFavorite) : store.quotes
    }

    private var glossarySection: some View {
        let words = glossaryWords
        return VStack(alignment: .leading, spacing: 10) {
            Text("Missed Words")
                .font(.system(.headline, design: .serif))
                .foregroundColor(Color("AppPrimary"))
            Text("Words the translator could not render. Tap to copy, swipe to remove.")
                .font(.system(.subheadline, design: .serif))
                .foregroundColor(Color.primary.opacity(0.7))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    AmberChip(title: "All", isOn: glossaryLanguage == nil) {
                        glossaryLanguage = nil
                    }
                    ForEach(glossaryLanguages) { language in
                        AmberChip(title: language.displayName, isOn: glossaryLanguage == language.rawValue) {
                            glossaryLanguage = glossaryLanguage == language.rawValue ? nil : language.rawValue
                        }
                    }
                }
            }

            FieldHint(text: copiedWord, isError: false)

            if store.sortedMissedWords.isEmpty {
                Text("No missed words yet. Translate a line and unknowns will collect here.")
                    .font(.system(.body, design: .serif))
                    .foregroundColor(Color.primary.opacity(0.65))
            } else if words.isEmpty {
                Text("No missed words in this language.")
                    .font(.system(.body, design: .serif))
                    .foregroundColor(Color.primary.opacity(0.65))
            } else {
                ForEach(words) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Button {
                            UIPasteboard.general.string = item.word
                            copiedWord = "Copied “\(item.word)”."
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.word)
                                    .font(.system(.headline, design: .serif))
                                    .foregroundColor(Color.primary)
                                Text("\(TargetLanguage.displayName(for: item.language)) · seen \(item.count)×")
                                    .font(.system(.caption, design: .serif))
                                    .foregroundColor(Color.primary.opacity(0.55))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        Button {
                            store.deleteMissedWords(ids: [item.id])
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(Color.red.opacity(0.85))
                        }
                        .accessibilityLabel("Remove \(item.word)")
                    }
                    LedgerDivider()
                }
            }
        }
    }

    private var glossaryWords: [MissedWord] {
        let source = store.sortedMissedWords
        guard let glossaryLanguage else { return source }
        return source.filter { $0.language == glossaryLanguage }
    }

    private var glossaryLanguages: [TargetLanguage] {
        TargetLanguage.allCases.filter { language in
            store.missedWords.contains { $0.language == language.rawValue }
        }
    }
}

struct FlashcardSessionView: View {
    let quotes: [Quote]
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var revealed = false
    @State private var deck: [Quote] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("Close") { dismiss() }
                    .font(.system(.body, design: .serif).weight(.semibold))
                    .foregroundColor(Color("AppAccent"))
                Spacer()
                if !deck.isEmpty {
                    Text("\(index + 1) of \(deck.count)")
                        .font(.system(.headline, design: .serif))
                        .foregroundColor(Color("AppPrimary"))
                }
                Spacer()
                Button("Shuffle") {
                    reshuffle()
                }
                .font(.system(.body, design: .serif).weight(.semibold))
                .foregroundColor(Color("AppAccent"))
                .opacity(deck.count > 1 ? 1 : 0)
                .disabled(deck.count <= 1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            LibraryBanner(imageName: "BannerPen")
                .padding(.horizontal, 16)

            if deck.isEmpty {
                EmptyQuotesPanel(
                    title: "Empty Deck",
                    detail: "There are no lines in this set of cards."
                )
                .padding(16)
            } else {
                let quote = deck[index]
                ScrollView {
                    ParchmentStage {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(quote.bookTitle)
                                .font(.system(.caption, design: .serif).weight(.semibold))
                                .foregroundColor(Color("AppPrimary"))
                            Text(quote.text)
                                .font(.system(.title2, design: .serif))
                                .foregroundColor(Color.primary)
                            LedgerDivider()
                            if revealed {
                                Text(quote.translatedText)
                                    .font(.system(.title3, design: .serif))
                                    .foregroundColor(Color.primary)
                                Text(TargetLanguage.displayName(for: quote.language))
                                    .font(.system(.caption, design: .serif).weight(.semibold))
                                    .foregroundColor(Color("AppPrimary"))
                            } else {
                                Text("Tap the card to uncover the translation.")
                                    .font(.system(.body, design: .serif))
                                    .foregroundColor(Color.primary.opacity(0.6))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                revealed.toggle()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }

                HStack(spacing: 10) {
                    Button("Previous") { move(-1) }
                        .font(.system(.body, design: .serif).weight(.semibold))
                        .foregroundColor(Color("AppAccent"))
                        .frame(maxWidth: .infinity)
                        .disabled(deck.count <= 1)
                    AmberCTA(title: revealed ? "Hide" : "Reveal") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            revealed.toggle()
                        }
                    }
                    Button("Next") { move(1) }
                        .font(.system(.body, design: .serif).weight(.semibold))
                        .foregroundColor(Color("AppAccent"))
                        .frame(maxWidth: .infinity)
                        .disabled(deck.count <= 1)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .libraryBackdrop()
        .onAppear {
            deck = quotes.isEmpty ? [] : quotes
            index = 0
            revealed = false
        }
    }

    private func move(_ delta: Int) {
        guard !deck.isEmpty else { return }
        index = (index + delta + deck.count) % deck.count
        revealed = false
    }

    private func reshuffle() {
        deck = deck.shuffled()
        index = 0
        revealed = false
    }
}
