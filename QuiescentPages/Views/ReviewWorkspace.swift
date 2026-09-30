import SwiftUI
import UIKit

struct StudyWorkspace: View {
    @EnvironmentObject private var store: Store
    @State private var path = NavigationPath()
    @State private var draft: QuoteDraft?
    @State private var showCards = false
    @State private var dueOnly = true
    @State private var sessionDeck: [Quote] = []
    @State private var glossaryLanguage: String?
    @State private var copiedWord = ""

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    InkPanel {
                        studyBody
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .clearScrollBackground()
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
                .environmentObject(store)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("dataReset"))) { _ in
            path = NavigationPath()
            draft = nil
            dueOnly = true
            glossaryLanguage = nil
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Study")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundColor(Color("AppPrimary"))
            Text("Spaced cards, daily line, missed words with examples")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(Color.white.opacity(0.9))
        }
    }

    @ViewBuilder
    private var studyBody: some View {
        if store.sortedQuotes.isEmpty {
            EmptyQuotesPanel(
                title: "Nothing to Study Yet",
                detail: "Save a translation and this desk will schedule cards."
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
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(Color("AppPrimary"))
                Button {
                    path.append(daily.id)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(daily.text)
                            .font(.system(.title3, design: .rounded))
                            .foregroundColor(Color.primary)
                            .multilineTextAlignment(.leading)
                        Text(daily.translatedText)
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(Color.primary.opacity(0.75))
                            .multilineTextAlignment(.leading)
                        HStack {
                            Text(daily.bookTitle)
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .foregroundColor(Color("AppPrimary"))
                            Spacer()
                            Text(TargetLanguage.displayName(for: daily.language))
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(Color.primary.opacity(0.55))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color("AppAccent").opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var cardsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Spaced Review")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(Color("AppPrimary"))
            Text("\(store.dueQuotes.count) due now · grade each card to schedule the next pass.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(Color.primary.opacity(0.7))
            AmberChip(title: dueOnly ? "Due only" : "Whole shelf", isOn: dueOnly) {
                dueOnly.toggle()
            }
            AmberCTA(title: "Start Review", isEnabled: !availableCards.isEmpty) {
                sessionDeck = availableCards.shuffled()
                showCards = true
            }
            if dueOnly && availableCards.isEmpty {
                FieldHint(text: "Nothing due. Open whole shelf or add a new quote.", isError: false)
            }
        }
    }

    private var availableCards: [Quote] {
        dueOnly ? store.dueQuotes : store.quotes
    }

    private var glossarySection: some View {
        let words = glossaryWords
        return VStack(alignment: .leading, spacing: 10) {
            Text("Missed Words")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(Color("AppPrimary"))
            Text("Unknown dictionary words with example lines from your shelf.")
                .font(.system(.subheadline, design: .rounded))
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
                Text("No missed words yet. Fill from dictionary and unknowns collect here.")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(Color.primary.opacity(0.65))
            } else if words.isEmpty {
                Text("No missed words in this language.")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(Color.primary.opacity(0.65))
            } else {
                ForEach(words) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Button {
                                UIPasteboard.general.string = item.word
                                copiedWord = "Copied “\(item.word)”."
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.word)
                                        .font(.system(.headline, design: .rounded))
                                        .foregroundColor(Color.primary)
                                    Text("\(TargetLanguage.displayName(for: item.language)) · seen \(item.count)×")
                                        .font(.system(.caption, design: .rounded))
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
                        }
                        ForEach(store.glossaryExamples(for: item).prefix(2)) { example in
                            Button {
                                path.append(example.id)
                            } label: {
                                Text("“\(example.text)”")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundColor(Color("AppPrimary"))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            .buttonStyle(.plain)
                        }
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
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var revealed = false
    @State private var deck: [Quote] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("Close") { dismiss() }
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundColor(Color("AppAccent"))
                Spacer()
                if !deck.isEmpty {
                    Text("\(index + 1) of \(deck.count)")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(Color("AppPrimary"))
                }
                Spacer()
                Color.clear.frame(width: 48, height: 1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if deck.isEmpty {
                EmptyQuotesPanel(
                    title: "Empty Deck",
                    detail: "There are no lines in this set of cards."
                )
                .padding(16)
            } else {
                let quote = deck[index]
                ScrollView {
                    InkPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(quote.bookTitle)
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundColor(Color("AppPrimary"))
                            Text(quote.text)
                                .font(.system(.title2, design: .rounded))
                                .foregroundColor(Color.primary)
                            LedgerDivider()
                            if revealed {
                                Text(quote.translatedText)
                                    .font(.system(.title3, design: .rounded))
                                    .foregroundColor(Color.primary)
                                Text(TargetLanguage.displayName(for: quote.language))
                                    .font(.system(.caption, design: .rounded).weight(.semibold))
                                    .foregroundColor(Color("AppPrimary"))
                            } else {
                                Text("Reveal the translation, then grade how it felt.")
                                    .font(.system(.body, design: .rounded))
                                    .foregroundColor(Color.primary.opacity(0.6))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                revealed = true
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .clearScrollBackground()

                if revealed {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        gradeButton("Again", grade: .again)
                        gradeButton("Hard", grade: .hard)
                        gradeButton("Good", grade: .good)
                        gradeButton("Easy", grade: .easy)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                } else {
                    AmberCTA(title: "Reveal") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            revealed = true
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
        }
        .libraryBackdrop()
        .onAppear {
            deck = quotes
            index = 0
            revealed = false
        }
    }

    private func gradeButton(_ title: String, grade: ReviewGrade) -> some View {
        Button {
            gradeCurrent(grade)
        } label: {
            Text(title)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background {
                    Capsule()
                        .fill(Color("AppPrimary").opacity(grade == .again ? 0.55 : 1))
                }
        }
        .buttonStyle(.plain)
    }

    private func gradeCurrent(_ grade: ReviewGrade) {
        guard deck.indices.contains(index) else { return }
        let quote = deck[index]
        store.applyReview(quoteID: quote.id, grade: grade)
        if index >= deck.count - 1 {
            dismiss()
        } else {
            index += 1
            revealed = false
        }
    }
}
