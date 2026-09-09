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

