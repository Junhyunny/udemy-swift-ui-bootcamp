# `.delay()`로 애니메이션을 미루는 방식은 어떻게 동작하나

애니메이션 API 세 가지 비교는 [별도 문서](./animation-api-comparison.md)에, 암시적·명시적 구분은 [여기](./implicit-vs-explicit-animation.md)에 정리했다. 이 문서는 **`delay`의 동작 원리**를 다룬다.

## 질문이 나온 코드

`chapter-94/chapter-94/HomeView.swift`

```swift
private func startTimer() {
    withAnimation(Animation.easeInOut(duration: 0.65)) {
        viewModel.buttonAnimation.toggle()
    }
    // TODO, 이런 식으로 애니메이션에 딜레이를 주는 방식은 SwiftUI 아키텍처 관점에서
    //       어떻게 동작하는거야? 외부 큐에 담아두고 다시 가져와서 애니메이션을 실행하는 방식인가?
    withAnimation(Animation.easeIn.delay(0.6)) {
        viewModel.timerViewOffset = 0
    }
    viewModel.performNotification()
}
```

## 공부할 내용

### 짐작과 다르다 — 큐에 담아 두는 것이 아니다

**"외부 큐에 담아두고 다시 가져와서 실행"이 아니다.** 상태는 **즉시** 바뀌고, `delay`는 **애니메이션 곡선의 일부**로 처리된다.

핵심을 먼저 정리하면 이렇다.

```text
withAnimation(.easeIn.delay(0.6)) {
    viewModel.timerViewOffset = 0
}
```

1. **`timerViewOffset = 0`이 즉시 실행된다.** 상태는 이미 0이다
2. SwiftUI는 "이전 값에서 새 값으로 가는 애니메이션"을 등록한다
3. 그 애니메이션의 **곡선에 0.6초의 대기 구간이 포함**된다
4. 0.6초 동안은 이전 값을 그리고, 이후 0.6초~1.6초 구간에 보간이 진행된다

**즉 "나중에 실행"이 아니라 "지금 등록하되 처음 0.6초는 움직이지 않는 애니메이션"** 이다.

### 두 방식의 결정적 차이

혼동하기 쉬운 것은 이 코드와의 대비다.

```swift
// ① delay — 상태가 즉시 바뀐다
withAnimation(.easeIn.delay(0.6)) {
    viewModel.timerViewOffset = 0
}
print(viewModel.timerViewOffset)     // 0 — 이미 바뀌었다

// ② asyncAfter — 상태가 나중에 바뀐다
DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
    withAnimation(.easeIn) {
        viewModel.timerViewOffset = 0
    }
}
print(viewModel.timerViewOffset)     // 이전 값 — 아직 안 바뀌었다
```

**②가 질문이 짐작한 "큐에 담아 두는" 방식**이다. `DispatchQueue`가 실제로 그렇게 동작한다.

| | `.delay()` | `asyncAfter` + `withAnimation` |
| --- | --- | --- |
| 상태 변경 시점 | **즉시** | 0.6초 후 |
| 대기 주체 | **렌더링(애니메이션 곡선)** | 디스패치 큐 |
| 중간에 다른 변경이 오면 | 애니메이션이 재계산된다 | 예약된 블록이 그대로 실행된다 |
| 취소 | 새 애니메이션이 덮어쓴다 | `DispatchWorkItem`으로 직접 취소 |
| 상태 일관성 | **유지된다** | 0.6초간 어긋난다 |

**`.delay()`가 더 안전하다.** 상태와 화면이 어긋나는 구간이 없다.

### `Animation`은 값이다 — 그래서 조합된다

`delay`가 어떻게 동작하는지는 `Animation`의 정체를 보면 이해된다.

```swift
@frozen struct Animation
```

**`Animation`은 struct, 즉 값**이다. 곡선의 종류·지속 시간·지연·반복 횟수·속도를 담은 설정 묶음이다.

```swift
func delay(_ delay: TimeInterval) -> Animation
```

`delay`는 **새 `Animation` 값을 돌려주는 수식자**다. 원본을 바꾸지 않는다.

```swift
Animation.easeIn                    // 곡선만
Animation.easeIn.delay(0.6)         // + 0.6초 지연
Animation.easeIn.delay(0.6).speed(2)  // + 2배속
```

[애니메이션 API 문서](./animation-api-comparison.md)에서 다룬 다른 수식자들과 같은 방식이다.

| 수식자 | 효과 |
| --- | --- |
| `delay(_:)` | 시작을 미룬다 |
| `speed(_:)` | 재생 속도 배율 |
| `repeatCount(_:autoreverses:)` | 반복 횟수 |
| `repeatForever(autoreverses:)` | 무한 반복 |

**이들은 모두 `Animation` 값을 변형해 새 값을 만든다.** [값 타입의 일반적 패턴](./struct-vs-class.md)이다.

### SwiftUI 렌더링 관점에서

조금 더 들어가면 `Transaction`이 관여한다.

```swift
withAnimation(_ animation: Animation? = .default, _ body: () throws -> Result) rethrows -> Result
```

> This function sets the given `Animation` as the `animation` property of the thread's current `Transaction`.

**`withAnimation`은 "이 상태 변경에 이 애니메이션을 붙여라"를 트랜잭션에 심는다.** [명시적 애니메이션 문서](./implicit-vs-explicit-animation.md)에서 다룬 내용이다.

흐름을 정리하면 이렇다.

```text
① withAnimation이 Transaction에 Animation 값을 심는다
② 클로저가 실행되어 상태가 즉시 바뀐다
③ SwiftUI가 body를 재평가해 새 뷰 트리를 만든다
④ 이전 뷰와 새 뷰의 차이(offset 500 → 0)를 찾는다
⑤ 그 차이를 Animation 값에 따라 시간에 걸쳐 보간한다
      ↑ delay(0.6)은 여기서 "처음 0.6초는 t=0 상태 유지"로 반영된다
⑥ 매 프레임 렌더러가 현재 시각에 해당하는 값을 계산해 그린다
```

**`delay`는 ⑤단계의 곡선 정의에 들어가는 값**이다. 별도 스레드나 큐가 관여하지 않는다.

**보간 대상은 `Animatable` 값**이다. `CGFloat`, `Double`, `Angle`, `Color` 등이 해당하고, `timerViewOffset`이 `CGFloat`이라 보간이 가능하다.

### 이 코드에서 두 애니메이션이 겹치는 방식

```swift
withAnimation(.easeInOut(duration: 0.65)) {
    viewModel.buttonAnimation.toggle()        // ① 즉시 시작, 0.65초 진행
}
withAnimation(.easeIn.delay(0.6)) {
    viewModel.timerViewOffset = 0              // ② 0.6초 대기 후 진행
}
```

시간축으로 보면 이렇다.

```text
0s        0.6s      0.65s              1.6s
│─────────│─────────│──────────────────│
│  ① 버튼 애니메이션 (0.65초)           │
│                                       │
│         │  ② 타이머 뷰 슬라이드        │
          ↑ 여기서 시작
```

**버튼 애니메이션이 거의 끝날 때 타이머 뷰가 올라온다.** 순차적으로 보이게 만드는 연출이다.

**두 `withAnimation`이 독립적이라는 점이 중요하다.** 각각 별도 트랜잭션이므로 서로 간섭하지 않는다. 하나의 `withAnimation`에 두 상태를 넣으면 같은 곡선을 공유한다.

```swift
// 같은 애니메이션을 공유
withAnimation(.easeInOut) {
    viewModel.buttonAnimation.toggle()
    viewModel.timerViewOffset = 0
}
```

### `delay`를 쓸 때 주의할 점

**① 중간에 상태가 또 바뀌면 애니메이션이 재계산된다**

```swift
withAnimation(.easeIn.delay(0.6)) {
    offset = 0
}
// 0.3초 뒤에 다른 코드가
offset = 100        // ← 대기 중인 애니메이션이 이 값 기준으로 다시 잡힌다
```

`asyncAfter`와 달리 **예약된 동작이 따로 있는 것이 아니므로**, 새 상태 변경이 오면 그것을 기준으로 애니메이션이 다시 결정된다. 대체로 이쪽이 원하는 동작이다.

**② 완료 시점을 알기 어렵다**

`delay`는 언제 끝나는지 알려 주지 않는다. 완료 후 작업이 필요하면 `withAnimation`의 completion을 쓴다.

```swift
withAnimation(.easeIn.delay(0.6)) {
    viewModel.timerViewOffset = 0
} completion: {
    print("슬라이드 완료")
}
```

iOS 17+의 `withAnimation(_:completionCriteria:_:completion:)`이다.

**③ 순차 연출이 많아지면 관리가 어렵다**

`delay` 값을 하드코딩으로 맞추면 하나를 바꿀 때 나머지도 조정해야 한다. 단계가 많으면 [`phaseAnimator`](./phase-animator-parameters-and-phase-types.md)가 더 적합하다.

```swift
.phaseAnimator([Phase.initial, .buttonMoved, .timerShown], trigger: started) { view, phase in
    view.offset(y: phase.offset)
} animation: { phase in
    phase.animation
}
```

**④ 접근성 설정을 존중한다**

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

withAnimation(reduceMotion ? nil : .easeIn.delay(0.6)) {
    viewModel.timerViewOffset = 0
}
```

[`@Environment` 문서](./environment-property-wrapper.md)에서 다룬 접근성 값이다. `nil`을 넘기면 애니메이션 없이 즉시 반영된다.

### `asyncAfter`를 써야 하는 경우

**애니메이션이 아닌 "동작"을 미뤄야 할 때**다.

```swift
// 3초 후 자동으로 닫기
DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
    isPresented = false
}
```

`delay`는 애니메이션 곡선에만 영향을 주므로, **상태 자체를 나중에 바꿔야 하면** 스케줄링이 필요하다. 다만 현대적인 방법은 `Task`다.

```swift
.task {
    try? await Task.sleep(for: .seconds(3))
    isPresented = false
}
```

[`.task`](./task-modifier-and-async-lifecycle.md)를 쓰면 뷰가 사라질 때 자동 취소되므로 `DispatchQueue`보다 안전하다.

**판단 기준**

```text
미루고 싶은 것이 무엇인가?
  ├─ 애니메이션의 시작 → .delay()          ← 상태는 즉시 바뀐다
  └─ 상태 변경 자체   → Task.sleep 또는 asyncAfter
```

### 정리

```text
질문의 짐작과 다르다 — 큐에 담아 두는 것이 아니다

.delay()의 동작
  ① 상태는 즉시 바뀐다
  ② delay는 애니메이션 곡선의 일부로 처리된다
  ③ 처음 0.6초는 이전 값을 그리고, 이후 보간이 진행된다

Animation은 struct(값)이라 수식자로 조합된다
  .easeIn.delay(0.6).speed(2)
  delay, speed, repeatCount, repeatForever

withAnimation은 Transaction에 Animation 값을 심는다
  상태 변경 → body 재평가 → 차이 계산 → 곡선에 따라 보간

asyncAfter와의 차이
  .delay()    상태 즉시 변경, 렌더링이 대기       ← 더 안전하다
  asyncAfter  상태도 나중에 변경, 큐가 대기

상태 자체를 미뤄야 하면 Task.sleep (뷰 생명주기에 묶인다)
단계가 많아지면 phaseAnimator
```

## 학습 체크리스트

- [ ] `withAnimation(.easeIn.delay(0.6))` 직후에 `print(viewModel.timerViewOffset)`으로 값이 이미 0인지 확인한다.
- [ ] `delay`를 지우고 두 애니메이션이 동시에 실행되는 것을 관찰한다.
- [ ] `delay(2.0)`으로 늘려 대기 구간을 눈으로 확인한다.
- [ ] `asyncAfter`로 바꿔 구현하고 `print`로 상태 변경 시점 차이를 비교한다.
- [ ] 대기 중에 `timerViewOffset`을 다른 값으로 바꿔 애니메이션이 재계산되는지 본다.
- [ ] 두 `withAnimation`을 하나로 합쳐 같은 곡선을 공유하게 만들어 본다.
- [ ] `.speed(2)`를 추가해 수식자가 조합되는 것을 확인한다.
- [ ] `withAnimation(...) { } completion: { }`으로 완료 시점을 잡아 본다.
- [ ] `@Environment(\.accessibilityReduceMotion)`으로 애니메이션을 끄는 분기를 넣는다.
- [ ] `Animation`이 `struct`인지 정의로 점프해 확인한다.
- [ ] 같은 순차 연출을 `phaseAnimator`로 구현해 비교한다.
- [ ] `Task.sleep`으로 상태 변경 자체를 미루고 `.delay`와의 차이를 확인한다.

## 공식 참고 자료

- [Apple: Animation](https://developer.apple.com/documentation/swiftui/animation)
- [Apple: Animation.delay(_:)](https://developer.apple.com/documentation/swiftui/animation/delay(_:))
- [Apple: Animation.speed(_:)](https://developer.apple.com/documentation/swiftui/animation/speed(_:))
- [Apple: Animation.repeatCount(_:autoreverses:)](https://developer.apple.com/documentation/swiftui/animation/repeatcount(_:autoreverses:))
- [Apple: withAnimation(_:_:)](https://developer.apple.com/documentation/swiftui/withanimation(_:_:))
- [Apple: withAnimation(_:completionCriteria:_:completion:)](https://developer.apple.com/documentation/swiftui/withanimation(_:completioncriteria:_:completion:))
- [Apple: Transaction](https://developer.apple.com/documentation/swiftui/transaction)
- [Apple: Animatable](https://developer.apple.com/documentation/swiftui/animatable)
- [Apple: Animations](https://developer.apple.com/documentation/swiftui/animations)
- [Apple: EnvironmentValues.accessibilityReduceMotion](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion)
- [Apple: DispatchQueue.asyncAfter(deadline:execute:)](https://developer.apple.com/documentation/dispatch/dispatchqueue/asyncafter(deadline:execute:))
- [Apple: Task.sleep(for:tolerance:clock:)](https://developer.apple.com/documentation/swift/task/sleep(for:tolerance:clock:))
