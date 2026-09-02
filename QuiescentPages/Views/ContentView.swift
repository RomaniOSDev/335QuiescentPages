import SwiftUI

struct ContentView: View {
    @StateObject private var store = Store()
    @State private var destination: LibraryDestination = .quotes
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            BookmarkRail(destination: $destination, onSettings: { showSettings = true })
            Group {
                switch destination {
                case .quotes:
                    QuoteWorkspace()
                case .history:
                    HistoryWorkspace()
                case .log:
                    LogWorkspace()
                case .study:
                    ReviewWorkspace()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            destination = .quotes
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose Languages")
                .font(.system(.largeTitle, design: .serif).weight(.semibold))
                .foregroundColor(Color("AppPrimary"))
                .padding(.horizontal, 16)
                .padding(.top, 20)
            Text("Pick the tongues you want waiting at the desk. You can change this later.")
                .font(.system(.body, design: .serif))
                .foregroundColor(Color.white.opacity(0.92))
                .padding(.horizontal, 16)

            LibraryBanner(imageName: "BannerStack")
                .padding(.horizontal, 16)

            ScrollView {
                ParchmentStage {
                    VStack(alignment: .leading, spacing: 14) {
                        LanguageToggleList(selectedCodes: $selectedCodes)
                        FieldHint(text: hint)
                        AmberCTA(title: "Continue", isEnabled: !selectedCodes.isEmpty) {
                            if selectedCodes.isEmpty {
                                hint = "Choose at least one language."
                            } else {
                                hint = ""
                                store.completeLanguageSetup(selectedCodes)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .libraryBackdrop()
        .onAppear {
            selectedCodes = store.preferredLanguages
        }
    }
}
