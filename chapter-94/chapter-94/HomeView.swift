//
//  HomeView.swift
//  chapter-94
//
//  Created by 강준현 on 9/9/26.
//

import SwiftUI
import Combine

struct HomeView: View {
    @EnvironmentObject var viewModel: TimerViewModel
    @State private var progress: CGFloat = 1.0

    private var startButton: some View {
        Button(action: startTimer) {
            Circle()
                .fill(.blue.gradient)
                .frame(width: 80, height: 80)
                .overlay {
                    Text("Start")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                }
        }
        .disabled(viewModel.time == 0)
        .opacity(viewModel.time == 0 ? 0.5 : 1.0)
        .padding(.bottom, 35)
    }

    private func startTimer() {
        withAnimation(Animation.easeInOut(duration: 0.65)) {
            viewModel.buttonAnimation.toggle()
        }
        // TODO: [todos/animation-delay-scheduling.md](../../todos/animation-delay-scheduling.md)
        withAnimation(Animation.easeIn.delay(0.6)) {
            viewModel.timerViewOffset = 0
        }
        viewModel.performNotification()
    }

    @ViewBuilder
    func timerSlidingView(_ geo: GeometryProxy) -> some View {
        Rectangle()
            .fill(.blue.gradient)
            .overlay {
                Text("\(viewModel.formatTime(seconds: viewModel.selectedTime))")
                    .font(.system(size: 55, weight: .heavy))
                    .foregroundStyle(.white)
                    .countdownStyle($progress)
                    .onChange(of: viewModel.selectedTime) { _, newValue in
                        progress = CGFloat(newValue) / CGFloat(viewModel.time)
                    }
            }
            .frame(height: geo.size.height - viewModel.timerHeightChange)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .bottom
            )
            .ignoresSafeArea()
            .offset(y: viewModel.timerViewOffset)
    }

    // FIXME: [Architecture] 카운트다운의 핵심 규칙이 View 안에 있다.
    // - 현상: 1초마다 selectedTime 을 감소시키고, 0 이 되면 resetView() 를 호출하는
    //         '타이머가 어떻게 동작하는가'가 View 의 private 함수에 들어 있다.
    // - 문제: 이 로직은 화면 없이 단위 테스트할 수 있어야 하는데 GeometryProxy 에 묶여 불가능하다.
    //         View 를 재구성하면 도메인 규칙도 같이 깨진다.
    // - 개선: ViewModel 에 func tick() 을 두고 시간 감소/종료 판정을 옮긴다.
    //         진행 높이(progressHeight) 계산처럼 순수하게 화면 크기에 의존하는 부분만 View 에 남긴다.
    private func timerProgress(_ geo: GeometryProxy) {
        if viewModel.time > 0 && viewModel.selectedTime > 0
            && viewModel.buttonAnimation
        {
            viewModel.selectedTime -= 1
            let progressHeight = geo.size.height / CGFloat(viewModel.time)
            let diff = viewModel.time - viewModel.selectedTime
            withAnimation {
                viewModel.timerHeightChange = CGFloat(diff) * progressHeight
            }
            if viewModel.selectedTime == 0 {
                viewModel.resetView()
            }
        }
    }

    // FIXME: [Best Practice] 알림 권한 요청 결과(granted, error)를 빈 클로저로 버린다.
    // - 문제: 사용자가 거부해도 앱은 계속 알림을 예약하고, 타이머가 끝나도 아무 일도 일어나지 않는다.
    //         원인을 알 방법이 없다.
    // - 개선: granted 를 상태로 보관해 거부 시 설정 이동을 안내한다.
    //         async 버전 try await center.requestAuthorization(options:) 이 더 읽기 쉽다.
    // - 추가: View 가 UNUserNotificationCenter.delegate 를 직접 설정하는 것도 계층 위반이다.
    //         delegate 등록은 앱 시작 지점(App 또는 AppDelegate)에서 한 번만 한다.
    private func publishNotification() {
        // TODO: [todos/user-notifications-framework.md](../../todos/user-notifications-framework.md)
        UNUserNotificationCenter.current().requestAuthorization(options: [
            .alert, .sound, .badge,
        ]) { granted, error in }
        // TODO: [todos/user-notifications-framework.md](../../todos/user-notifications-framework.md)
        UNUserNotificationCenter.current().delegate = viewModel

    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    VStack {
                        CircularPickerView()
                            .environmentObject(viewModel)
                            .frame(height: geo.size.height * 0.8)

                        startButton
                    }
                    timerSlidingView(geo)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black.opacity(0.8))
                .ignoresSafeArea()
                // TODO: [todos/timer-publisher-and-onreceive.md](../../todos/timer-publisher-and-onreceive.md)
                // TODO: [todos/timer-publisher-and-onreceive.md](../../todos/timer-publisher-and-onreceive.md)
                // FIXME: [Best Practice] body 안에서 Timer publisher 를 직접 생성하고 있다.
                // - 문제: body 가 재평가될 때마다 새 publisher 가 만들어져 구독이 갈아끼워지고,
                //         기존 타이머는 정리 시점이 불분명해진다. 타이머는 화면이 필요 없을 때도 계속 돈다.
                // - 개선: publisher 를 프로퍼티(let timer = Timer.publish(...).autoconnect())로 한 번만 만들거나,
                //         카운트다운은 ViewModel 이 소유하고 View 는 결과만 그리게 한다.
                //         남은 시간 표시만 필요하면 Text(timerInterval:) / TimelineView 가 더 저렴하다.
                .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                    timerProgress(geo)
                }
            }
        }
        .onAppear {
            publishNotification()
        }
        .navigationTitle("Dev Techie Timer")
    }
}

