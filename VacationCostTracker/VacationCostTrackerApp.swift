import SwiftUI
import SwiftData
import UserNotifications

@main
struct VacationCostTrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var currencyManager = CurrencyManager()
    @State private var plaidService    = PlaidService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(currencyManager)
                .environment(plaidService)
        }
        .modelContainer(for: [Trip.self, SubTrip.self, Expense.self, PlaidLinkedAccount.self])
    }
}

// MARK: - App Delegate

/// Handles remote (silent) push notification registration and receipt.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        // Request notification permission (for bank notification parsing feature)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
        return true
    }

    // ── Device token ──────────────────────────────────────────────────────────

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Register with backend so APNs silent pushes can reach this device
        PlaidService().registerDeviceToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("AppDelegate: push registration failed — \(error.localizedDescription)")
    }

    // ── Silent push ───────────────────────────────────────────────────────────
    // Flow: Plaid webhook → backend → APNs silent push → this method
    // We spin up a model container and trigger a Plaid sync in the background.

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard let type = userInfo["type"] as? String, type == "plaid_sync" else {
            completionHandler(.noData)
            return
        }
        Task {
            do {
                let container = try ModelContainer(
                    for: Trip.self, SubTrip.self, Expense.self, PlaidLinkedAccount.self
                )
                let service = PlaidService()
                await service.sync(modelContext: container.mainContext)
                completionHandler(.newData)
            } catch {
                print("AppDelegate: background sync failed — \(error)")
                completionHandler(.failed)
            }
        }
    }

    // ── Foreground notification ───────────────────────────────────────────────

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // ── Notification tap → attempt to parse bank transaction ─────────────────

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let body = response.notification.request.content.body
        Task { @MainActor in
            do {
                let container = try ModelContainer(
                    for: Trip.self, SubTrip.self, Expense.self, PlaidLinkedAccount.self
                )
                NotificationParser.tryLog(notificationBody: body, modelContext: container.mainContext)
            } catch {
                print("AppDelegate: notification log failed — \(error)")
            }
            completionHandler()
        }
    }
}
