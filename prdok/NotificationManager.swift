//
//  NotificationManager.swift
//  prdok
//
//  Created by David Horňák on 03.02.2026.
//

import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
        
    // requests for noti access, returns true if noti access granted
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    // should return either .notDetermined, .authorized or .denied
    func getAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }
}
