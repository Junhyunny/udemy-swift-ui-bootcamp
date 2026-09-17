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
// FIXME: [Architecture] 한 ViewModel 이 서로 다른 4가지 책임을 모두 지고 있다.
//   (1) 타이머 도메인 상태      : time, selectedTime
//   (2) 레이아웃 수치          : timerViewOffset, timerHeightChange (UIScreen 값까지 직접 읽는다)
//   (3) 애니메이션 플래그       : buttonAnimation
//   (4) 시스템 알림 스케줄 + 델리게이트 : performNotification, userNotificationCenter(_:willPresent:)
// - 문제: 변경 이유가 4개라 무엇을 고쳐도 이 파일을 건드리게 된다(SRP 위반).
//         특히 (4) 때문에 NSObject 를 상속해야 했고, 그 탓에 값 의미의 상태 컨테이너가
//         참조 타입 + Objective-C 런타임에 묶였다. 순수 로직만 테스트하기가 어렵다.
// - 개선:
//   * (4)를 protocol NotificationScheduling + final class NotificationScheduler 로 분리해
//     TimerViewModel 은 주입받아 쓰기만 한다. 델리게이트 등록은 App/AppDelegate 가 담당한다.
//   * (2),(3)은 View 의 @State 로 내린다. ViewModel 은 '남은 시간'만 알면 되고
//     그것을 어떤 오프셋으로 그릴지는 화면의 관심사다.
//   * 그러면 NSObject 상속이 사라지고 @Observable 매크로로 전환할 수 있다.
final class TimerViewModel: NSObject, UNUserNotificationCenterDelegate,
    ObservableObject
{
    @Published var time: Int = 0
    @Published var selectedTime: Int = 0
    @Published var buttonAnimation: Bool = false
    // TODO: [todos/uiscreen-main-deprecated.md](../../todos/uiscreen-main-deprecated.md)
    // FIXME: [Best Practice] UIScreen.main 은 iOS 16 부터 deprecated 이고, 멀티윈도우/분할화면에서 틀린 값을 준다.
    // - 문제: ViewModel 이 화면 크기를 직접 아는 것 자체가 계층 위반이다.
    //         회전이나 Stage Manager 크기 변경에도 반응하지 못한다.
    // - 개선: 레이아웃 값은 View 에서 GeometryReader 로 얻어 ViewModel 에 주입하거나,
    //         오프셋을 "숨김/표시" 같은 의미 있는 상태(enum)로 모델링한다.
    @Published var timerViewOffset: CGFloat = UIScreen.main.bounds.height
    @Published var timerHeightChange: CGFloat = 0
    // TODO: [todos/implicitly-unwrapped-optional.md](../../todos/implicitly-unwrapped-optional.md)
    // FIXME: [Best Practice] 암묵적 언래핑 옵셔널(Date!)은 nil 접근 시 크래시한다.
    // - 문제: resetView() 에서 실제로 nil 을 대입하는데도 타입은 "항상 값이 있다"고 선언한다.
    //         옵셔널의 안전장치를 스스로 꺼둔 셈이다.
    // - 개선: Date? 로 선언하고 사용처에서 guard let 으로 푼다.
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
