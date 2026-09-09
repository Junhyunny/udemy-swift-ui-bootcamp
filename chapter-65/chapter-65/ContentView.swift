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

extension NotificationCenter: @unchecked Sendable {}

#Preview {
    ContentView()
}
