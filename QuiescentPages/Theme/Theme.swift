import SwiftUI
import UIKit

extension View {
    func libraryBackdrop() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                Color("AppBackground")
                    .overlay {
                        Image("BgBook")
                            .resizable()
                            .scaledToFill()
                            .opacity(0.22)
                    }
                    .clipped()
                    .ignoresSafeArea()
            }
    }
}

enum Theme {
    static let pageCorner: CGFloat = 3
    static let shadowRadius: CGFloat = 8
}

struct LibraryBanner: View {
    let imageName: String

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 96)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            .shadow(color: Color("AppPrimary").opacity(0.28), radius: Theme.shadowRadius, y: 3)
    }
}

struct PageFold: View {
    var body: some View {
        GeometryReader { geo in
            let size = min(22.0, geo.size.width * 0.1)
            Path { path in
                path.move(to: CGPoint(x: geo.size.width - size, y: 0))
                path.addLine(to: CGPoint(x: geo.size.width, y: 0))
                path.addLine(to: CGPoint(x: geo.size.width, y: size))
                path.closeSubpath()
            }
            .fill(Color("AppAccent").opacity(0.55))
            Path { path in
                path.move(to: CGPoint(x: geo.size.width - size, y: 0))
                path.addLine(to: CGPoint(x: geo.size.width - size, y: size))
                path.addLine(to: CGPoint(x: geo.size.width, y: size))
            }
            .stroke(Color("AppPrimary").opacity(0.4), lineWidth: 0.7)
        }
        .allowsHitTesting(false)
    }
}

struct ParchmentStage<Content: View>: View {
    var fillsAvailable: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: fillsAvailable ? .infinity : nil, alignment: .topLeading)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.pageCorner, style: .continuous)
                        .fill(Color("AppSurface").opacity(0.42))
                        .offset(x: 7, y: 8)
                    RoundedRectangle(cornerRadius: Theme.pageCorner, style: .continuous)
                        .fill(Color("AppSurface").opacity(0.68))
                        .offset(x: 3, y: 4)
                    RoundedRectangle(cornerRadius: Theme.pageCorner, style: .continuous)
                        .fill(Color.white.opacity(0.94))
                        .overlay {
                            Color("AppAccent").opacity(0.08)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.pageCorner, style: .continuous))
                        }
                        .overlay(alignment: .topTrailing) {
                            PageFold()
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.pageCorner, style: .continuous)
                                .stroke(Color("AppPrimary").opacity(0.28), lineWidth: 0.8)
                        }
                        .shadow(color: Color("AppPrimary").opacity(0.26), radius: Theme.shadowRadius, y: 4)
                }
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
                .font(.system(.headline, design: .serif))
                .foregroundColor(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background {
                    LinearGradient(
                        colors: isEnabled
                            ? [Color("AppPrimary"), Color("AppAccent")]
                            : [Color("AppSurface"), Color("AppSurface")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(
                        color: Color("AppPrimary").opacity(isEnabled ? 0.35 : 0),
                        radius: 7,
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
                .font(.system(.caption, design: .serif))
                .foregroundColor(isError ? Color.red.opacity(0.9) : Color.primary.opacity(0.65))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct EmptyQuotesPanel: View {
    var title: String = "No Quotes Yet"
    var detail: String = "Gather a line from a book and set it into another tongue."

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "quote.bubble")
                .font(.system(size: 46, weight: .regular))
                .foregroundColor(Color("AppPrimary"))
            Text(title)
                .font(.system(.title2, design: .serif).weight(.semibold))
                .foregroundColor(Color.primary)
            Text(detail)
                .font(.system(.body, design: .serif))
                .foregroundColor(Color.primary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 12)
    }
}

struct BookmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let notch = min(18, rect.height * 0.28)
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width / 2, y: rect.height - notch))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

struct BookmarkTab: View {
    let destination: LibraryDestination
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: destination.symbolName)
                    .font(.system(size: 16, weight: .semibold))
                Text(destination.title)
                    .font(.system(.caption2, design: .serif).weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(isSelected ? Color.white : Color("AppPrimary"))
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .padding(.bottom, 18)
            .background {
                Group {
                    if isSelected {
                        BookmarkShape()
                            .fill(
                                LinearGradient(
                                    colors: [Color("AppPrimary"), Color("AppAccent")],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    } else {
                        BookmarkShape()
                            .fill(Color("AppSurface"))
                    }
                }
                .shadow(
                    color: Color("AppPrimary").opacity(isSelected ? 0.35 : 0.18),
                    radius: isSelected ? 8 : 5,
                    y: 3
                )
            }
        }
        .buttonStyle(.plain)
        .offset(y: isSelected ? 8 : -4)
        .accessibilityLabel(destination.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct BookmarkRail: View {
    @Binding var destination: LibraryDestination
    let onSettings: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            ForEach(LibraryDestination.allCases) { item in
                BookmarkTab(
                    destination: item,
                    isSelected: destination == item,
                    action: { destination = item }
                )
            }
            Spacer(minLength: 8)
            Button(action: onSettings) {
                Text("Colophon")
                    .font(.system(size: 10, weight: .semibold, design: .serif))
                    .foregroundColor(Color("AppPrimary"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .overlay(
                        Rectangle()
                            .stroke(Color("AppPrimary").opacity(0.7), lineWidth: 0.8)
                    )
            }
            .accessibilityLabel("Settings")
            .padding(.top, 8)
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .padding(.bottom, 2)
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
                        Image(systemName: isOn ? "bookmark.fill" : "bookmark")
                            .foregroundColor(Color("AppPrimary"))
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(language.displayName)
                                .font(.system(.headline, design: .serif))
                                .foregroundColor(Color.primary)
                            Text(language.nativeHint)
                                .font(.system(.caption, design: .serif))
                                .foregroundColor(Color.primary.opacity(0.65))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isOn ? Color("AppAccent").opacity(0.22) : Color("AppSurface").opacity(0.18))
                            .shadow(color: Color("AppPrimary").opacity(isOn ? 0.16 : 0), radius: 6, y: 2)
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
                        .font(.system(.caption, design: .serif).weight(.semibold))
                        .foregroundColor(isOn ? Color.white : Color("AppPrimary"))
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background {
                            Group {
                                if isOn {
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color("AppPrimary"), Color("AppAccent")],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                } else {
                                    Capsule()
                                        .fill(Color("AppSurface").opacity(0.25))
                                }
                            }
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
            .fill(Color("AppPrimary").opacity(0.28))
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
                .font(.system(.caption, design: .serif).weight(.semibold))
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
            .font(.system(.body, design: .serif))
            .padding(10)
            .background(Color("AppSurface").opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct NewQuoteButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.white)
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color("AppPrimary"), Color("AppAccent")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color("AppPrimary").opacity(0.3), radius: 6, y: 2)
                }
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityLabel("New Quote")
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
