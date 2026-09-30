import StoreKit
import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCodes: [String] = []
    @State private var showResetConfirm = false
    @State private var languageHint = ""
    @State private var reminderHint = ""
    @State private var reminderFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button("Close") { dismiss() }
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundColor(Color("AppAccent"))
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Settings")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundColor(Color("AppPrimary"))
                    Text("Languages, reminders, and desk reset")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.9))

                    InkPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Preferred Languages")
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(Color("AppPrimary"))
                            LanguageToggleList(selectedCodes: $selectedCodes)
                            FieldHint(text: languageHint)
                            AmberCTA(title: "Save Languages", isEnabled: !selectedCodes.isEmpty) {
                                if selectedCodes.isEmpty {
                                    languageHint = "Choose at least one language."
                                } else {
                                    languageHint = ""
                                    store.updatePreferredLanguages(selectedCodes)
                                }
                            }
                        }
                    }

                    InkPanel {
                        VStack(alignment: .leading, spacing: 10) {
                            reminderRow
                            FieldHint(text: reminderHint, isError: reminderFailed)
                        }
                    }

                    InkPanel {
                        VStack(spacing: 0) {
                            settingsLine("Rate Quiescent Pages", action: requestReview)
                            LedgerDivider().padding(.vertical, 8)
                            settingsLine("Privacy") { AppLinks.open(AppLinks.privacy) }
                            LedgerDivider().padding(.vertical, 8)
                            settingsLine("Terms") { AppLinks.open(AppLinks.terms) }
                        }
                    }

                    Button {
                        showResetConfirm = true
                    } label: {
                        Text("Reset All Data")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundColor(Color.red.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.red.opacity(0.45), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 36)
            }
            .clearScrollBackground()
            .scrollDismissesKeyboard(.immediately)
        }
        .libraryBackdrop()
        .onAppear {
            selectedCodes = store.preferredLanguages
            if store.remindersEnabled {
                reminderHint = "A note will arrive each evening at 8:00."
                reminderFailed = false
            }
        }
        .alert("Reset All Data?", isPresented: $showResetConfirm) {
            Button("Reset All Data", role: .destructive) {
                store.resetAllData()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Quotes, books, languages, missed words, and schedules will clear. Seed classics reload afterward.")
        }
    }

    private var reminderRow: some View {
        Toggle(isOn: Binding(
            get: { store.remindersEnabled },
            set: { enabled in
                if enabled {
                    ReminderScheduler.apply(enabled: true) { success in
                        store.setRemindersEnabled(success)
                        if success {
                            reminderHint = "A note will arrive each evening at 8:00."
                            reminderFailed = false
                        } else {
                            reminderHint = "Notifications were not allowed."
                            reminderFailed = true
                        }
                    }
                } else {
                    ReminderScheduler.apply(enabled: false)
                    store.setRemindersEnabled(false)
                    reminderHint = ""
                    reminderFailed = false
                }
            }
        )) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Evening Reminder")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(Color.primary)
                Text("Nudge to capture or review at 8:00")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(Color.primary.opacity(0.65))
            }
        }
        .tint(Color("AppPrimary"))
    }

    private func settingsLine(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(Color.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(Color("AppPrimary").opacity(0.5))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func requestReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else { return }
        SKStoreReviewController.requestReview(in: scene)
    }
}
