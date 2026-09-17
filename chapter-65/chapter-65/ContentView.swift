//
//  ContentView.swift
//  chapter-65
//
//  Created by 강준현 on 9/8/26.
//

import Observation
import SwiftUI

struct ContentView: View {
    @State private var systemNotification = SystemNotificationExample()
    
    
    var body: some View {
        // FIXME: [Best Practice] body 안에서 var 로 선언했지만 재대입이 없다(컴파일 경고).
        // - 개선: let layout = ... 으로 바꾸거나, 아예 computed property 로 빼서 body 를 가볍게 한다.
        var layout = systemNotification.orientation == .portrait ? AnyLayout(VStackLayout()) : AnyLayout(HStackLayout())
        NavigationStack {
            layout {
                ReceiverView()
                SenderView()
            }
            .navigationTitle("DevTechie.com")
            .onChange(of: systemNotification.orientation) { oldValue, newValue in
                print(oldValue, "->" ,newValue)
            }
        }
    }
}

struct ReceiverView: View {
    @State private var counter = 0
    @State private var additionalInfo = ""
    var body: some View {
        ZStack {
            Color.mint.opacity(0.2)
            VStack {
                Text("Received **\(counter)** messages")
                if !additionalInfo.isEmpty {
                    Text("*\(additionalInfo)*")
                }
            }
        }
        .onAppear {
            // TODO: [todos/task-priority-and-scheduling.md](../../todos/task-priority-and-scheduling.md)
            Task(priority: .background) {
                await receiveNotifications()
            }
        }
    }

    private func receiveNotifications() async {
        let center = NotificationCenter.default
        let name = Notification.Name("DTAlert")
        // TODO: [todos/for-await-async-sequence.md](../../todos/for-await-async-sequence.md)
        for await notification in center.notifications(named: name) {
            if let userInfo = notification.userInfo,
                // TODO: [todos/swift-type-casting.md](../../todos/swift-type-casting.md)
                let moreInfo = userInfo["Course"] as? DTCourse
            {
                await MainActor.run {
                    additionalInfo = "\(moreInfo.name) by: \(moreInfo.author)"
                }
            }
            // TODO: [todos/main-actor-and-ios-threading.md](../../todos/main-actor-and-ios-threading.md)
            await MainActor.run {
                counter += 1
            }
        }
    }
}

struct SenderView: View {
    var body: some View {
        ZStack {
            Color.orange.opacity(0.2)
            Button("Send Notification") {
                // TODO: [todos/notification-center.md](../../todos/notification-center.md)
                let center = NotificationCenter.default
                let name = Notification.Name("DTAlert")

                // TODO: [todos/notification-center.md](../../todos/notification-center.md)
                let course = DTCourse(
                    name: "Practical SwiftData in SwiftUI",
                    author: "DevTechie.com"
                )
                let additionalInfo = [
                    // "Course": "Practical SwiftData in SwiftUI"
                    "Course": course
                ]

                // TODO: [todos/notification-center.md](../../todos/notification-center.md)
                center.post(
                    name: name,
                    object: nil,
                    userInfo: additionalInfo
                )
            }
        }
    }
}

struct DTCourse: Codable {
    var name: String
    var author: String
}

enum DTOrientation {
    case portrait
    case landscape
}

@Observable
// TODO: [todos/final-keyword.md](../../todos/final-keyword.md)
final class SystemNotificationExample {
    let center = NotificationCenter.default
    var orientation: DTOrientation = DTOrientation.portrait

    init() {
        Task(priority: .background) {
            await orientationChangeNotification()
        }
    }

    @MainActor
    func orientationChangeNotification() async {
        let name = UIDevice.orientationDidChangeNotification
        for await notification in center.notifications(named: name) {
            if let device = notification.object as? UIDevice {
                if device.orientation.isPortrait {
                    orientation = .portrait
                } else {
                    orientation = .landscape
                }
            }
        }
    }
}

// FIXME: [Best Practice] 내가 소유하지 않은 타입에 @unchecked Sendable 을 붙이는 소급 적합성(retroactive conformance).
// - 문제: 컴파일러 경고를 끄는 것일 뿐 실제 스레드 안전성은 아무것도 보장하지 않는다.
//         애플이 나중에 같은 conformance 를 추가하면 중복 선언으로 빌드가 깨지고,
//         다른 모듈이 같은 선언을 하면 충돌한다.
// - 개선: 이 줄을 지우고, NotificationCenter 를 actor 경계 밖으로 넘기지 않도록 설계한다.
//         필요하면 for await 루프를 도는 메서드 자체를 @MainActor 로 고정하고
//         center 는 그 안에서 지역 변수로 얻는다.
extension NotificationCenter: @unchecked Sendable {}

#Preview {
    ContentView()
}
