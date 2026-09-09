//
//  TimerViewModel.swift
//  chapter-94
//
//  Created by 강준현 on 9/9/26.
//

import Combine
import Foundation
import SwiftUI
import UserNotifications

// TODO: [todos/state-wrapper-decision-guide.md](../../todos/state-wrapper-decision-guide.md)
// TODO: [todos/user-notifications-framework.md](../../todos/user-notifications-framework.md)
final class TimerViewModel: NSObject, UNUserNotificationCenterDelegate,
    ObservableObject
{
    @Published var time: Int = 0
    @Published var selectedTime: Int = 0
    @Published var buttonAnimation: Bool = false
    // TODO: [todos/uiscreen-main-deprecated.md](../../todos/uiscreen-main-deprecated.md)
    @Published var timerViewOffset: CGFloat = UIScreen.main.bounds.height
    @Published var timerHeightChange: CGFloat = 0
    // TODO: [todos/implicitly-unwrapped-optional.md](../../todos/implicitly-unwrapped-optional.md)
    @Published var leftTime: Date!

    func formatTime(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    func resetView() {
        withAnimation {
            time = 0
            selectedTime = 0
            timerHeightChange = 0
            timerViewOffset = UIScreen.main.bounds.height
            buttonAnimation = false
            leftTime = nil
        }
    }

    func performNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Time's Up! Notification from Jun.com"
        content.body = "Your session is over."
        content.sound = UNNotificationSound.default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(time),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: "TIMER",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print(error.localizedDescription)
            }
        }
    }
    
    // TODO: [todos/user-notifications-framework.md](../../todos/user-notifications-framework.md)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // TODO: [todos/user-notifications-framework.md](../../todos/user-notifications-framework.md)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        resetView()
        completionHandler()
    }
}
