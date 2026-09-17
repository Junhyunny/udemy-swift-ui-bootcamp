//
//  CircularPickerView.swift
//  chapter-94
//
//  Created by 강준현 on 9/9/26.
//

import SwiftUI

struct CircularPickerView: View {
    // TODO: [todos/049-state-wrapper-decision-guide.md](../../../todos/049-state-wrapper-decision-guide.md)
    @EnvironmentObject var timerVM: TimerViewModel
    // FIXME: [Architecture] 같은 값이 두 곳에 저장되어 진실의 출처가 둘이다.
    // - 현상: 선택값을 CircularPickerViewModel.selectedValue 에 저장하면서,
    //         동시에 드래그 제스처에서 timerVM.time 과 timerVM.selectedTime 에도 써 넣는다.
    //         (selected * 5 라는 변환 규칙까지 View 의 제스처 안에 있다)
    // - 문제: 두 상태가 어긋날 수 있고, 어느 쪽이 정답인지 코드만 봐서는 알 수 없다.
    //         TimerViewModel.resetView() 가 time 을 0 으로 되돌려도 피커의 selectedValue 는 그대로다.
    // - 개선: 재사용 컴포넌트는 상태를 소유하지 말고 @Binding var selection: Int 로 받는다.
    //         소유는 상위(TimerViewModel)가 하고, '5분 단위' 같은 도메인 변환도 그쪽으로 옮긴다.
    //         그러면 CircularPickerViewModel 자체가 필요 없어지고 컴포넌트는 순수 표현이 된다.
    @StateObject private var viewModel = CircularPickerViewModel()
    private let radius: CGFloat = 150
    private let centerPoint = CGPoint(x: 150, y: 150)

    private var backCircle: some View {
        Circle()
            .stroke(.white.opacity(0.3), lineWidth: 40)
            .frame(width: radius * 2, height: radius * 2)
            .shadow(color: .white, radius: 10)
    }

    private var centerToNumberLine: some View {
        Path { path in
            path.move(to: centerPoint)
            path.addLine(to: pointForNumber(viewModel.selectedValue))
        }
        .stroke(.blue.opacity(0.5), lineWidth: 2)
    }

    private var numberCircle: some View {
        Circle()
            .fill(.blue)
            .frame(width: 40, height: 40)
            .position(pointForNumber(viewModel.selectedValue))
            .overlay {
                Text("\(viewModel.selectedValue * 5)")
                    .foregroundStyle(.primary)
                    .font(.title)
                    .frame(width: 40, height: 40)
                    .padding()
                    .background(.blue.gradient, in: Circle())
            }
    }

    private var numberForTimer: some View {
        ForEach(1...12, id: \.self) { number in
            Text("\(number * 5)")
                .font(
                    number == viewModel.selectedValue
                        ? .system(size: 16) : .system(size: 14)
                )
                .bold(number == viewModel.selectedValue)
                .foregroundStyle(
                    number == viewModel.selectedValue ? .white : .black
                )
                .position(pointForNumber(number))
        }
    }

    private var circularDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let selected = numberFromLocation(value.location)
                viewModel.selectValue(selected)
                timerVM.time = selected * 5
                timerVM.selectedTime = selected * 5
            }
    }

    private func pointForNumber(_ number: Int) -> CGPoint {
        let angle = 2 * .pi * CGFloat(number - 3) / 12
        return CGPoint(
            x: centerPoint.x + radius * cos(angle),
            y: centerPoint.y + radius * sin(angle)
        )
    }

    private func numberFromLocation(_ location: CGPoint) -> Int {
        let angle = atan2(
            location.y - centerPoint.y,
            location.x - centerPoint.x
        )
        var normalizedAngle = angle + .pi / 2
        if normalizedAngle < 0 {
            normalizedAngle += 2 * .pi
        }
        let number = Int(round((normalizedAngle / (2 * .pi)) * 12)) + 1
        return number > 12 ? 1 : number
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                backCircle
                centerToNumberLine
                numberCircle
                numberForTimer
            }
            .frame(width: radius * 2, height: radius * 2)
            .gesture(circularDragGesture)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

#Preview {
    CircularPickerView()
}
