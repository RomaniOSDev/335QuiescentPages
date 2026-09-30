import Foundation
import UserNotifications

enum ReminderScheduler {
    static let requestID = "daily.line"

    static func apply(enabled: Bool, completion: ((Bool) -> Void)? = nil) {
        if !enabled {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [requestID])
            completion?(true)
            return
        }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted {
                        schedule()
                    }
                    DispatchQueue.main.async { completion?(granted) }
                }
            case .authorized, .provisional, .ephemeral:
                schedule()
                DispatchQueue.main.async { completion?(true) }
            default:
                DispatchQueue.main.async { completion?(false) }
            }
        }
    }

    static func rescheduleIfAuthorized() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                schedule()
            default:
                break
            }
        }
    }

    private static func schedule() {
        let content = UNMutableNotificationContent()
        content.title = "Quiescent Pages"
        content.body = "Capture a page or review a due card on your reading desk."
        content.sound = .default

        var components = DateComponents()
        components.hour = 20
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
