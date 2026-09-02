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
                    .font(.system(.body, design: .serif).weight(.semibold))
                    .foregroundColor(Color("AppAccent"))
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)

            ScrollView {
                VStack(alignment: .center, spacing: 18) {
                    Text("COLOPHON")
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .tracking(6)
                        .foregroundColor(Color("AppPrimary"))
                    Rectangle()
                        .fill(Color("AppPrimary"))
                        .frame(width: 72, height: 1)

                    LibraryBanner(imageName: "BannerLamp")
                        .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Preferred Languages")
                            .font(.system(.headline, design: .serif))
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
                    .padding(.top, 8)

                    reminderRow
                    FieldHint(text: reminderHint, isError: reminderFailed)

                    colophonLine("Rate Us", action: requestReview)
                    colophonLine("Privacy") { AppLinks.open(AppLinks.privacy) }
                    colophonLine("Terms") { AppLinks.open(AppLinks.terms) }

                    Button {
                        showResetConfirm = true
                    } label: {
                        VStack(spacing: 6) {
                            Rectangle().fill(Color.red.opacity(0.55)).frame(height: 0.6)
                            Text("Reset All Data")
                                .font(.system(.body, design: .serif).italic())
                                .foregroundColor(Color.red.opacity(0.9))
                            Rectangle().fill(Color.red.opacity(0.55)).frame(height: 0.6)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 36)
            }
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
            Text("Quotes, history, languages, missed words, and dates will be cleared. This cannot be undone.")
        }
    }

    private var reminderRow: some View {
        Button {
            let next = !store.remindersEnabled
            ReminderScheduler.apply(enabled: next) { granted in
                if next && !granted {
                    store.setRemindersEnabled(false)
                    reminderHint = "Notifications are turned off for this app."
                    reminderFailed = true
                } else {
                    store.setRemindersEnabled(next)
                    reminderHint = next ? "A note will arrive each evening at 8:00." : ""
                    reminderFailed = false
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: store.remindersEnabled ? "bell.fill" : "bell")
                    .foregroundColor(Color("AppPrimary"))
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Reminder")
                        .font(.system(.headline, design: .serif))
                        .foregroundColor(Color.primary)
                    Text("Save a line at 8:00 in the evening")
                        .font(.system(.caption, design: .serif))
                        .foregroundColor(Color.primary.opacity(0.65))
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(store.remindersEnabled ? Color("AppAccent").opacity(0.22) : Color("AppSurface").opacity(0.18))
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func colophonLine(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .foregroundColor(Color("AppPrimary"))
                Rectangle()
                    .fill(Color("AppPrimary").opacity(0.45))
                    .frame(height: 0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .accessibilityLabel(title)
    }

    private func requestReview() {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? scenes.compactMap { $0 as? UIWindowScene }.first
        if let windowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }
}
