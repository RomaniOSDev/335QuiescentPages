import SwiftUI

struct HistoryWorkspace: View {
    @EnvironmentObject private var store: Store
    @State private var path = NavigationPath()
    @State private var query = ""
    @State private var editMode: EditMode = .inactive
    @State private var draft: QuoteDraft?
    @State private var pendingDeleteIDs: [UUID] = []
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 12) {
                header
                LibraryBanner(imageName: LibraryDestination.history.bannerName)
                ParchmentStage(fillsAvailable: true) {
                    historyBody
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
            query = ""
            draft = nil
            editMode = .inactive
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("History")
                    .font(.system(.largeTitle, design: .serif).weight(.semibold))
                    .foregroundColor(Color("AppPrimary"))
                Text("Every rendering kept in order")
                    .font(.system(.subheadline, design: .serif))
                    .foregroundColor(Color.white.opacity(0.9))
            }
            Spacer()
            if !filtered.isEmpty {
                Button(editMode.isEditing ? "Done" : "Edit") {
                    withAnimation {
                        editMode = editMode.isEditing ? .inactive : .active
                    }
                }
                .font(.system(.body, design: .serif).weight(.semibold))
                .foregroundColor(Color("AppAccent"))
            }
        }
    }

    private var filtered: [Quote] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let source = store.sortedHistory
        guard !needle.isEmpty else { return source }
        return source.filter { quote in
            quote.text.lowercased().contains(needle)
                || quote.translatedText.lowercased().contains(needle)
                || quote.bookTitle.lowercased().contains(needle)
                || TargetLanguage.displayName(for: quote.language).lowercased().contains(needle)
        }
    }

    @ViewBuilder
    private var historyBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Search titles and lines", text: $query)
                .font(.system(.body, design: .serif))
                .padding(10)
                .background(Color("AppSurface").opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .submitLabel(.search)

            if store.sortedHistory.isEmpty {
                EmptyQuotesPanel(
                    title: "No History Yet",
                    detail: "Saved translations will gather here in the order you keep them."
                )
                .frame(minHeight: 240)
            } else if filtered.isEmpty {
                EmptyQuotesPanel(
                    title: "No Matching Translations",
                    detail: "Try another word from the book title or the line itself."
                )
                .frame(minHeight: 240)
            } else {
                List {
                    ForEach(filtered) { quote in
                        Button {
                            path.append(quote.id)
                        } label: {
                            QuoteLedgerRow(quote: quote)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
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
                        pendingDeleteIDs = indexSet.compactMap { filtered[safe: $0]?.id }
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
}
