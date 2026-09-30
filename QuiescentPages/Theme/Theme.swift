import SwiftUI
import UIKit

extension View {
    func libraryBackdrop() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                DeskAtmosphere()
                    .ignoresSafeArea()
            }
    }

    func clearScrollBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Color.clear)
    }
}

enum Theme {
    static let panelCorner: CGFloat = 18
    static let dockHeight: CGFloat = 72
    static let contentBottomInset: CGFloat = 96
    static let shadowRadius: CGFloat = 10
}

struct DeskAtmosphere: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color("AppBackground"),
                    Color("AppBackground").opacity(0.92),
                    Color("AppPrimary").opacity(0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            GeometryReader { geo in
                Path { path in
                    let step: CGFloat = 28
                    var x: CGFloat = -geo.size.height
                    while x < geo.size.width + geo.size.height {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x + geo.size.height, y: geo.size.height))
                        x += step
                    }
                }
                .stroke(Color("AppAccent").opacity(0.08), lineWidth: 1)
            }
            VStack {
                Spacer()
                Ellipse()
                    .fill(Color("AppAccent").opacity(0.18))
                    .frame(height: 220)
                    .blur(radius: 40)
                    .offset(y: 60)
            }
        }
    }
}

struct InkPanel<Content: View>: View {
    var fillsAvailable: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: fillsAvailable ? .infinity : nil, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: Theme.panelCorner, style: .continuous)
                    .fill(Color.white.opacity(0.94))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color("AppPrimary"), Color("AppAccent")],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 5)
                            .padding(.vertical, 14)
                            .padding(.leading, 8)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.panelCorner, style: .continuous)
                            .stroke(Color("AppPrimary").opacity(0.18), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.18), radius: Theme.shadowRadius, y: 6)
            }
    }
}

struct AmberCTA: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundColor(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: isEnabled
                                    ? [Color("AppPrimary"), Color("AppAccent")]
                                    : [Color("AppSurface"), Color("AppSurface")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(
                            color: Color("AppPrimary").opacity(isEnabled ? 0.35 : 0),
                            radius: 8,
                            y: 3
                        )
                }
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
    }
}

struct FieldHint: View {
    let text: String
    var isError: Bool = true

    var body: some View {
        if !text.isEmpty {
            Text(text)
                .font(.system(.caption, design: .rounded))
                .foregroundColor(isError ? Color.red.opacity(0.9) : Color.primary.opacity(0.65))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct EmptyQuotesPanel: View {
    var title: String = "No Lines Yet"
    var detail: String = "Scan a page or type a quote to start your shelf."

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "viewfinder")
                .font(.system(size: 42, weight: .regular))
                .foregroundColor(Color("AppPrimary"))
            Text(title)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundColor(Color.primary)
            Text(detail)
                .font(.system(.body, design: .rounded))
                .foregroundColor(Color.primary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 12)
    }
}

struct DestinationDock: View {
    @Binding var destination: LibraryDestination
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(LibraryDestination.allCases) { item in
                Button {
                    destination = item
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.symbolName)
                            .font(.system(size: 16, weight: .semibold))
                        Text(item.title)
                            .font(.system(.caption2, design: .rounded).weight(.semibold))
                    }
                    .foregroundColor(destination == item ? Color.white : Color("AppPrimary"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        if destination == item {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color("AppPrimary"), Color("AppAccent")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(destination == item ? .isSelected : [])
            }
            Button(action: onSettings) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color("AppPrimary"))
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color("AppSurface").opacity(0.35)))
            }
            .accessibilityLabel("Settings")
        }
        .padding(8)
        .background {
            Capsule()
                .fill(Color.white.opacity(0.92))
                .shadow(color: Color.black.opacity(0.2), radius: 14, y: 6)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }
}

struct LanguageToggleList: View {
    @Binding var selectedCodes: [String]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(TargetLanguage.allCases) { language in
                let isOn = selectedCodes.contains(language.rawValue)
                Button {
                    toggle(language.rawValue)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(Color("AppPrimary"))
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(language.displayName)
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(Color.primary)
                            Text(language.nativeHint)
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(Color.primary.opacity(0.65))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isOn ? Color("AppAccent").opacity(0.22) : Color("AppSurface").opacity(0.18))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggle(_ code: String) {
        if let index = selectedCodes.firstIndex(of: code) {
            selectedCodes.remove(at: index)
        } else {
            selectedCodes.append(code)
        }
    }
}

struct LanguageChipRow: View {
    let languages: [TargetLanguage]
    @Binding var selectedCode: String

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(languages) { language in
                let isOn = selectedCode == language.rawValue
                Button {
                    selectedCode = language.rawValue
                } label: {
                    Text(language.displayName)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundColor(isOn ? Color.white : Color("AppPrimary"))
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background {
                            Capsule()
                                .fill(
                                    isOn
                                        ? AnyShapeStyle(
                                            LinearGradient(
                                                colors: [Color("AppPrimary"), Color("AppAccent")],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        : AnyShapeStyle(Color("AppSurface").opacity(0.25))
                                )
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct LedgerDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color("AppPrimary").opacity(0.18))
            .frame(height: 1)
    }
}

struct AmberChip: View {
    let title: String
    var isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundColor(isOn ? Color.white : Color("AppPrimary"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    Capsule()
                        .fill(
                            isOn
                                ? AnyShapeStyle(
                                    LinearGradient(
                                        colors: [Color("AppPrimary"), Color("AppAccent")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                : AnyShapeStyle(Color("AppSurface").opacity(0.25))
                        )
                }
        }
        .buttonStyle(.plain)
    }
}

struct EditorField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(.body, design: .rounded))
            .padding(10)
            .background(Color("AppSurface").opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct StatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundColor(Color("AppPrimary"))
            Text(title)
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .foregroundColor(Color.primary.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color("AppAccent").opacity(0.16))
        }
    }
}

struct ShelfSpine: View {
    let tone: Int

    var body: some View {
        let colors: [Color] = [
            Color("AppPrimary"),
            Color("AppAccent"),
            Color("AppBackground"),
            Color("AppSurface")
        ]
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(colors[abs(tone) % colors.count])
            .frame(width: 10)
    }
}

struct DisableNavBarHits: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        Controller()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    final class Controller: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            apply()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            apply()
        }

        private func apply() {
            navigationController?.setNavigationBarHidden(true, animated: false)
            navigationController?.navigationBar.isUserInteractionEnabled = false
        }
    }
}

enum KeyboardDismissInstaller {
    static func attach() {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        for window in windows {
            let already = window.gestureRecognizers?.contains { $0.name == KeyboardDismissHandler.recognizerName } ?? false
            if already { continue }
            let tap = UITapGestureRecognizer(target: KeyboardDismissHandler.shared, action: #selector(KeyboardDismissHandler.dismiss))
            tap.cancelsTouchesInView = false
            tap.delegate = KeyboardDismissHandler.shared
            tap.name = KeyboardDismissHandler.recognizerName
            window.addGestureRecognizer(tap)
        }
    }
}

private final class KeyboardDismissHandler: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissHandler()
    static let recognizerName = "qp.keyboard.dismiss"

    @objc func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let current = view {
            if current is UITextField || current is UITextView {
                return false
            }
            view = current.superview
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}
