import UIKit

enum AppLinks {
    static let privacy = URL(string: "https://quiescent335pages.site/privacy/439")
    static let terms = URL(string: "https://quiescent335pages.site/terms/439")

    static func open(_ url: URL?) {
        guard let url else { return }
        UIApplication.shared.open(url)
    }
}
