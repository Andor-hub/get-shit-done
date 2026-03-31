import Foundation
import UserNotifications

/// Service for all UNUserNotificationCenter operations.
/// Follows the HabitLogService pattern: @MainActor enum, static methods, no stored state.
@MainActor
enum NotificationService {

    // MARK: - Authorization

    /// Requests notification authorization if not yet determined.
    /// Returns true if authorized or provisional, false if denied or error.
    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    // MARK: - Scheduling

    /// Schedules a daily repeating notification for the given habit.
    /// Uses habit.reminderTime for the hour/minute components.
    /// No-ops silently if reminderTime is nil.
    static func scheduleReminder(for habit: HabitSchemaV1.Habit) async {
        guard let reminderTime = habit.reminderTime else { return }

        let content = UNMutableNotificationContent()
        content.title = habit.name
        content.body = ""
        content.sound = .default

        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let identifier = "reminder-\(habit.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // Non-fatal: silently ignore scheduling errors
        }
    }

    // MARK: - Cancellation

    /// Cancels the pending notification for the given habit.
    static func cancelReminder(for habit: HabitSchemaV1.Habit) {
        let identifier = "reminder-\(habit.id.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// Cancels pending notifications for all habits that are completed today.
    /// Called on app foreground to avoid reminding the user about already-done habits.
    static func cancelRemindersForCompletedHabits(_ habits: [HabitSchemaV1.Habit]) {
        let identifiers = habits
            .filter { $0.reminderTime != nil && HabitLogService.isCompleted(habit: $0) }
            .map { "reminder-\($0.id.uuidString)" }
        guard !identifiers.isEmpty else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
