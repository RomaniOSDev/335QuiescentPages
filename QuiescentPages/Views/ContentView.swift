import SwiftUI

struct ContentView: View {
    @StateObject private var store = Store()
    @State private var destination: LibraryDestination = .library
    @State private var showSettings = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch destination {
                case .library:
                    LibraryWorkspace()
                case .desk:
                    DeskWorkspace()
                case .study:
                    StudyWorkspace()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, Theme.contentBottomInset)

            DestinationDock(destination: $destination, onSettings: { showSettings = true })
        }
        .libraryBackdrop()
        .environmentObject(store)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(store)
        }
        .sheet(isPresented: languageSetupBinding) {
            LanguageSetupView()
                .environmentObject(store)
                .interactiveDismissDisabled()
        }
        .onAppear {
            KeyboardDismissInstaller.attach()
            if store.remindersEnabled {
                ReminderScheduler.rescheduleIfAuthorized()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("dataReset"))) { _ in
            showSettings = false
            destination = .library
        }
    }

    private var languageSetupBinding: Binding<Bool> {
        Binding(
            get: { store.needsLanguageSetup },
            set: { _ in }
        )
    }
}

struct LanguageSetupView: View {
    @EnvironmentObject private var store: Store
    @State private var selectedCodes: [String] = []
    @State private var hint = ""
    @State private var step = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(step == 0 ? "Reading Desk" : "Choose Tongues")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundColor(Color("AppPrimary"))
                    Text(step == 0
                         ? "Capture lines from real pages, keep them under each book on your shelf, then review with spaced cards."
                         : "Pick the languages waiting at the desk. You can change this later in Settings.")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.92))

                    InkPanel {
                        if step == 0 {
                            VStack(alignment: .leading, spacing: 14) {
                                onboardingRow(symbol: "doc.text.viewfinder", title: "Page Scan", detail: "Photograph a book page and pull the quote with on-device OCR.")
                                onboardingRow(symbol: "books.vertical.fill", title: "Book Shelves", detail: "Every line belongs to a book with notes and spine color.")
                                onboardingRow(symbol: "rectangle.on.rectangle.angled", title: "Spaced Study", detail: "Grade cards and the desk schedules the next review.")
                                AmberCTA(title: "Continue") { step = 1 }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 14) {
                                LanguageToggleList(selectedCodes: $selectedCodes)
                                FieldHint(text: hint)
                                AmberCTA(title: "Open Library", isEnabled: !selectedCodes.isEmpty) {
                                    if selectedCodes.isEmpty {
                                        hint = "Choose at least one language."
                                    } else {
                                        hint = ""
                                        store.completeLanguageSetup(selectedCodes)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 28)
                .padding(.bottom, 36)
            }
            .clearScrollBackground()
        }
        .libraryBackdrop()
        .onAppear {
            selectedCodes = store.preferredLanguages
        }
    }

    private func onboardingRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color("AppPrimary"))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(Color.primary)
                Text(detail)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(Color.primary.opacity(0.7))
            }
        }
    }
}
