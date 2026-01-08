import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    private var previousStates: [Int: Bool] = [:]
    
    func checkAndNotifyStatusChanges(monitors: [Monitor]) {
        for monitor in monitors {
            let currentState = monitor.isUp
            let previousState = previousStates[monitor.id] ?? currentState
            
            if previousState != currentState {
                sendNotification(
                    title: monitor.name,
                    body: currentState ? "✅ Service is UP" : "❌ Service is DOWN",
                    badge: currentState ? nil : NSNumber(value: 1)
                )
            }
            
            previousStates[monitor.id] = currentState
        }
    }
    
    private func sendNotification(title: String, body: String, badge: NSNumber?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        if let badge = badge {
            content.badge = badge
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Fehler beim Senden der Benachrichtigung: \(error)")
            }
        }
    }
}
