# `phaseAnimator`의 파라미터와 phase에 담을 수 있는 것

암시적 애니메이션과 `withAnimation`의 차이는 [별도 문서](./implicit-vs-explicit-animation.md)에, `animation(_:value:)`의 `value`가 필요한 이유는 [여기](./animation-value-trigger.md)에 정리했다. 이 문서는 **`phaseAnimator`** 에 집중한다.

## 질문이 나온 코드

`chapter-53/chapter-53/ContentView.swift`

```swift
.phaseAnimator(
    [1.0, 0.5],
    trigger: animate,
    content: { view, phase in
        view
            .scaleEffect(phase)
            .opacity(phase)
    }
)
```

## 1부 — 파라미터들의 역할

### 시그니처 전체

```swift
nonisolated func phaseAnimator<Phase>(
    _ phases: some Sequence,
    trigger: some Equatable,
    @ViewBuilder content: @escaping (PlaceholderContentView<Self>, Phase) -> some View,
    animation: @escaping (Phase) -> Animation? = { _ in .default }
) -> some View where Phase : Equatable
```

파라미터가 넷이고, 예제는 그중 셋을 쓴다.

### ① `phases` — 거쳐 갈 단계들의 목록

애니메이션이 순서대로 지나갈 값들이다. 예제의 `[1.0, 0.5]`가 여기 해당한다.

타입이 `some Sequence`라는 점이 중요하다. 배열뿐 아니라 어떤 시퀀스든 된다. 요소 타입 `Phase`의 유일한 제약은 `Equatable`이다 — 2부의 주제다.

동작 규칙은 Apple 문서가 정확히 설명한다.

> When the modified view first appears, this modifier renders its content closure using the **first phase** as input to the closure, along with a proxy for the modified view.
>
> Later, when the value of the trigger input changes, the modifier provides its content closure with the value of the **second phase**. (…) The next time the trigger input changes, this procedure repeats using successive phases until reaching the **last phase**, at which point the modifier **loops back to the first phase**.

즉 예제는 이렇게 순환한다.

```text
화면 등장       → phase = 1.0  (원래 크기, 불투명)
탭 1회          → phase = 0.5  (절반 크기, 반투명)  ← 애니메이션
탭 2회          → phase = 1.0  (처음으로 되돌아감)  ← 애니메이션
탭 3회          → phase = 0.5
...
```

**중요한 점: 탭 한 번에 한 단계씩만 간다.** 단계가 셋이면 세 번 눌러야 한 바퀴다.

```swift
.phaseAnimator([1.0, 0.5, 1.5], trigger: animate) { view, phase in
    view.scaleEffect(phase)
}
// 탭 → 0.5 → 탭 → 1.5 → 탭 → 1.0 → ...
```

### ② `trigger` — 다음 단계로 넘어가는 신호

`some Equatable`이다. **이 값이 바뀔 때마다** 다음 phase로 이동한다.

예제의 `animate`가 그 역할이다.

```swift
@State private var animate = false

.onTapGesture {
    animate.toggle()      // 값이 바뀜 → 다음 phase로
}
```

여기서 자주 오해하는 지점이 있다. **`animate`의 값 자체(`true`/`false`)는 아무 의미가 없다.** 오직 "바뀌었다"는 사실만 쓰인다. `Bool` 대신 `Int` 카운터를 써도 똑같이 동작한다.

```swift
@State private var tapCount = 0

.onTapGesture { tapCount += 1 }
.phaseAnimator([1.0, 0.5], trigger: tapCount) { ... }
```

이 성질은 [`animation(_:value:)`의 `value`](./animation-value-trigger.md)와 같은 발상이다. 값이 무엇인지가 아니라 **변했는지**가 신호다.

### ③ `content` — 각 단계에서 어떻게 보일지

파라미터가 **두 개**인 클로저다. 예제의 `{ view, phase in ... }`가 그것이다.

**첫 번째 `view`** — 원래 뷰의 대역(proxy)이다.

```swift
@ViewBuilder content: @escaping (PlaceholderContentView<Self>, Phase) -> some View
```

타입이 `PlaceholderContentView<Self>`인데, Apple은 이 타입을 직접 다루지 말라고 한다.

> You don't use this type directly. Instead SwiftUI creates this type on your behalf.

이름 그대로 자리 표시자다. `.phaseAnimator`가 붙은 원래 뷰(예제에서는 `VStack`)를 대신하고, 여기에 효과를 얹으면 실제 뷰에 적용된다. [`ViewModifier`의 `content`](./view-modifier-protocol.md)와 같은 개념이다.

**두 번째 `phase`** — 현재 단계의 값이다. 예제에서는 `1.0` 또는 `0.5`가 들어온다.

```swift
content: { view, phase in
    view
        .scaleEffect(phase)   // 크기
        .opacity(phase)       // 투명도
}
```

두 효과에 같은 값을 쓰고 있어서 크기가 줄면 흐려지기도 한다. 두 값을 따로 두고 싶다면 2부의 방법이 필요하다.

`@ViewBuilder`가 붙어 있으므로 `if`나 `switch`로 분기할 수도 있다.

```swift
content: { view, phase in
    if phase > 0.7 {
        view.scaleEffect(phase)
    } else {
        view.scaleEffect(phase).blur(radius: 3)
    }
}
```

### ④ `animation` — 단계별 애니메이션 곡선

**기본값이 있어서 예제는 생략했다.**

```swift
animation: @escaping (Phase) -> Animation? = { _ in .default }
```

`Animation`이 아니라 **`(Phase) -> Animation?` 클로저**라는 점이 핵심이다. 단계마다 다른 곡선을 줄 수 있다.

```swift
.phaseAnimator([1.0, 0.5], trigger: animate) { view, phase in
    view.scaleEffect(phase).opacity(phase)
} animation: { phase in
    phase == 0.5 ? .spring(duration: 0.3) : .easeOut(duration: 0.8)
}
```

`Animation?`이라 `nil`을 돌려주면 그 단계는 **애니메이션 없이 즉시** 전환된다. 깜빡임 같은 효과에 쓸 수 있다.

### `trigger`가 없는 오버로드

같은 이름의 다른 버전이 있다.

```swift
nonisolated func phaseAnimator<Phase>(
    _ phases: some Sequence,
    @ViewBuilder content: @escaping (PlaceholderContentView<Self>, Phase) -> some View,
    animation: @escaping (Phase) -> Animation? = { _ in .default }
) -> some View
```

> **Right away**, the modifier provides its content closure with the value of the second phase. (…) **As soon as the animation completes**, the procedure repeats using successive phases until reaching the last phase, at which point the modifier loops back to the first phase.

`trigger`가 없으면 **사용자 입력 없이 자동으로 계속 반복**된다. 로딩 인디케이터나 주목을 끄는 애니메이션에 쓴다.

```swift
Circle()
    .phaseAnimator([1.0, 1.3]) { view, phase in
        view.scaleEffect(phase)
    }
// 탭 없이도 계속 커졌다 작아졌다 반복
```

| | `trigger` 있음 | `trigger` 없음 |
| --- | --- | --- |
| 다음 단계로 가는 계기 | trigger 값 변화 | 애니메이션 완료 |
| 사용자 입력 | 필요 | 불필요 |
| 용도 | 버튼 피드백, 반응 애니메이션 | 로딩, 펄스, 주의 환기 |

### 다른 애니메이션 API의 파라미터 비교

질문의 "다른 함수 시그니처"에 해당하는 부분이다.

**`animation(_:value:)`**

```swift
func animation<V>(_ animation: Animation?, value: V) -> some View where V : Equatable
```

- `animation` — 곡선 하나
- `value` — 이 값이 바뀔 때 애니메이션

가장 단순하다. 상태 A에서 B로 가는 **한 번의 전환**만 다룬다.

**`withAnimation(_:_:)`**

```swift
func withAnimation<Result>(_ animation: Animation? = .default, _ body: () throws -> Result) rethrows -> Result
```

- `animation` — 곡선
- `body` — 이 안에서 일어난 상태 변경을 애니메이션

명시적 애니메이션이다. [비교 문서](./implicit-vs-explicit-animation.md) 참조.

**`keyframeAnimator(initialValue:trigger:content:keyframes:)`**

```swift
func keyframeAnimator<Value>(
    initialValue: Value,
    trigger: some Equatable,
    @ViewBuilder content: @escaping @Sendable (PlaceholderContentView<Self>, Value) -> some View,
    @KeyframesBuilder<Value> keyframes: @escaping (Value) -> some Keyframes
) -> some View
```

`phaseAnimator`와 형제 API다. 차이가 분명하다.

| | `phaseAnimator` | `keyframeAnimator` |
| --- | --- | --- |
| 단계 정의 | 값 목록 | 시간축 위의 키프레임 |
| 각 단계 지속 시간 | 애니메이션 곡선이 결정 | **직접 지정** |
| 여러 속성 | 하나의 phase 값으로 파생 | **속성별로 독립적인 트랙** |
| 복잡도 | 단순 | 정교 |

`keyframeAnimator`에는 주의사항이 있다.

> Note that the content closure will be updated on **every frame** while animating, so avoid performing any expensive operations directly within content.

`phaseAnimator`는 단계가 바뀔 때만 호출되지만, `keyframeAnimator`는 매 프레임 호출된다.

**`Animation` 타입 자체의 수식자들**

`animation` 파라미터에 넘기는 값도 조합할 수 있다.

> - Delay the start of the animation by using the `delay(_:)` modifier.
> - Repeat the animation by using the `repeatCount(_:autoreverses:)` or `repeatForever(autoreverses:)` modifiers.
> - Change the speed of the animation by using the `speed(_:)` modifier.

```swift
.easeIn.repeatCount(3)
.spring(duration: 0.4).delay(0.2)
.linear.speed(2)
```

## 2부 — phase에 객체를 담을 수 있는가

### 결론: 된다. `Equatable`이기만 하면 무엇이든 가능하다

제약은 시그니처에 딱 하나뿐이다.

```swift
where Phase : Equatable
```

`Double`이어야 한다는 규칙은 없다. 예제가 `[1.0, 0.5]`를 쓴 것은 단지 그 값을 `scaleEffect`와 `opacity`에 바로 넘길 수 있어서다.

그리고 질문의 의도대로 **여러 뷰 요소의 상태를 한 phase에 담는 것**이 오히려 이 API의 권장 사용법이다.

### 방법 ① `enum` — 가장 관용적

연관값 없는 `enum`은 `Equatable`이 자동 합성되므로 바로 쓸 수 있다. [enum과 Hashable 문서](./enum-hashable-conformance.md)에서 다룬 합성 규칙이 그대로 적용된다.

```swift
enum AnimationPhase: CaseIterable {
    case initial, expanded, faded

    var scale: Double {
        switch self {
        case .initial:  1.0
        case .expanded: 1.3
        case .faded:    0.5
        }
    }

    var opacity: Double {
        switch self {
        case .initial:  1.0
        case .expanded: 1.0
        case .faded:    0.3
        }
    }

    var rotation: Angle {
        switch self {
        case .initial:  .zero
        case .expanded: .degrees(15)
        case .faded:    .degrees(-15)
        }
    }
}
```

```swift
.phaseAnimator(AnimationPhase.allCases, trigger: animate) { view, phase in
    view
        .scaleEffect(phase.scale)
        .opacity(phase.opacity)
        .rotationEffect(phase.rotation)
} animation: { phase in
    switch phase {
    case .initial:  .spring(duration: 0.5)
    case .expanded: .easeOut(duration: 0.2)
    case .faded:    .easeIn(duration: 0.4)
    }
}
```

**장점이 뚜렷하다.**

- 단계마다 **여러 속성을 독립적으로** 지정할 수 있다 — 예제처럼 크기와 투명도가 묶이지 않는다
- 단계에 이름이 생겨 코드가 읽힌다
- `CaseIterable`을 붙이면 `allCases`로 목록을 자동 생성한다
- `switch`에서 case 누락을 컴파일러가 잡아 준다

### 방법 ② `struct` — 값 조합이 자유로울 때

```swift
struct CardPhase: Equatable {
    var scale: Double
    var opacity: Double
    var offsetY: CGFloat
    var blur: CGFloat
}

let phases: [CardPhase] = [
    CardPhase(scale: 1.0, opacity: 1.0, offsetY: 0,   blur: 0),
    CardPhase(scale: 0.9, opacity: 0.6, offsetY: -20, blur: 2),
    CardPhase(scale: 1.1, opacity: 1.0, offsetY: 0,   blur: 0),
]
```

```swift
.phaseAnimator(phases, trigger: animate) { view, phase in
    view
        .scaleEffect(phase.scale)
        .opacity(phase.opacity)
        .offset(y: phase.offsetY)
        .blur(radius: phase.blur)
}
```

저장 프로퍼티가 모두 `Equatable`이면 `Equatable`도 자동 합성된다.

### 방법 ③ 튜플은 안 된다

```swift
.phaseAnimator([(1.0, 0.5), (0.5, 1.0)], trigger: animate) { ... }   // ⚠️
```

Swift의 튜플은 프로토콜을 채택할 수 없어 `Equatable` 제약을 만족하지 못한다. `struct`를 쓰는 이유다.

### "여러 view 요소의 페이즈"에 대해

질문에 "여러 view 요소들의 페이즈를 처리할 수 있나"라는 표현이 있는데, 두 가지로 나눠 볼 수 있다.

**A. 한 뷰의 여러 속성** — 위의 `enum`/`struct` 방식으로 해결된다.

**B. 서로 다른 뷰들이 각각 다른 단계** — 이건 `phaseAnimator` 하나로는 안 된다. `phaseAnimator`는 **자신이 붙은 뷰 하나**에 효과를 적용하기 때문이다.

예제처럼 원 세 개를 각각 다르게 움직이려면 개별로 붙여야 한다.

```swift
VStack {
    ForEach(Array([Color.red, .orange, .green].enumerated()), id: \.offset) { index, color in
        Circle()
            .fill(color.gradient)
            .phaseAnimator([1.0, 0.5], trigger: animate) { view, phase in
                view.scaleEffect(phase)
            } animation: { _ in
                .spring(duration: 0.5).delay(Double(index) * 0.1)   // 순차 지연
            }
    }
}
```

`delay`를 인덱스에 비례해 주면 물결처럼 순차적으로 움직인다. 지금 예제는 `VStack` 전체에 하나만 붙어 있어 세 원이 **함께** 움직인다.

### 참고 — 지금 예제의 한 가지 특징

`phaseAnimator`가 `navigationTitle`과 `onTapGesture` **뒤에** 붙어 있다.

```swift
VStack { ... }
    .navigationTitle("Junhyunny's Example")
    .onTapGesture { animate.toggle() }
    .phaseAnimator([1.0, 0.5], trigger: animate) { ... }
```

modifier 순서상 `phaseAnimator`가 가장 바깥이므로, `scaleEffect`와 `opacity`가 **탭 제스처가 붙은 뷰 전체**에 적용된다. 뷰가 작아지고 반투명해져도 탭 영역은 함께 줄어든다. `opacity`가 0에 가까운 단계를 넣으면 보이지 않는 뷰를 탭해야 하는 상황이 생길 수 있으니, 그럴 때는 `onTapGesture`를 더 바깥으로 옮기는 것이 안전하다.

주석 처리된 `.scaleEffect(animate ? 1.0 : 0.5)`는 `phaseAnimator` 도입 전의 방식이다. 둘을 비교해 보면 차이가 분명하다 — 전자는 두 상태를 오가는 것이고, 후자는 **여러 단계를 순환**한다.

## 학습 체크리스트

- [ ] `phases`를 `[1.0, 0.5, 1.5]`로 늘리고 탭할 때마다 한 단계씩 가는 것을 확인한다.
- [ ] 마지막 단계 이후 첫 단계로 되돌아가는지 확인한다.
- [ ] `trigger`를 `Int` 카운터로 바꿔도 동일하게 동작하는지 확인한다.
- [ ] `animation:` 파라미터를 추가해 단계별로 다른 곡선을 준다.
- [ ] `animation:`에서 `nil`을 돌려줘 즉시 전환되는 단계를 만든다.
- [ ] `trigger`를 제거한 오버로드로 바꿔 자동 반복되는 것을 확인한다.
- [ ] `content`에서 `view`를 쓰지 않고 다른 뷰를 반환해 원래 뷰가 사라지는 것을 본다.
- [ ] `enum AnimationPhase`를 만들어 크기·투명도·회전을 독립적으로 지정한다.
- [ ] `CaseIterable`의 `allCases`를 `phases`로 넘겨 본다.
- [ ] `struct` phase를 만들어 네 가지 속성을 한 번에 다뤄 본다.
- [ ] 튜플 배열을 `phases`로 넘겨 컴파일 에러를 확인한다.
- [ ] 세 원에 각각 `phaseAnimator`를 붙이고 `delay`로 순차 애니메이션을 만든다.
- [ ] `phaseAnimator`를 `onTapGesture`보다 안쪽에 두고 탭 영역이 어떻게 달라지는지 본다.
- [ ] 주석 처리된 `.scaleEffect(animate ? 1.0 : 0.5)`를 되살려 `phaseAnimator`와 비교한다.
- [ ] 같은 효과를 `keyframeAnimator`로 만들어 보고 시간 제어의 차이를 체감한다.

## 공식 참고 자료

- [Apple: view.phaseAnimator(_:trigger:content:animation:)](https://developer.apple.com/documentation/swiftui/view/phaseanimator(_:trigger:content:animation:))
- [Apple: view.phaseAnimator(_:content:animation:)](https://developer.apple.com/documentation/swiftui/view/phaseanimator(_:content:animation:))
- [Apple: PhaseAnimator](https://developer.apple.com/documentation/swiftui/phaseanimator)
- [Apple: PhaseAnimator.init(_:trigger:content:animation:)](https://developer.apple.com/documentation/swiftui/phaseanimator/init(_:trigger:content:animation:))
- [Apple: PlaceholderContentView](https://developer.apple.com/documentation/swiftui/placeholdercontentview)
- [Apple: view.keyframeAnimator(initialValue:trigger:content:keyframes:)](https://developer.apple.com/documentation/swiftui/view/keyframeanimator(initialvalue:trigger:content:keyframes:))
- [Apple: Animation](https://developer.apple.com/documentation/swiftui/animation)
- [Apple: view.animation(_:value:)](https://developer.apple.com/documentation/swiftui/view/animation(_:value:))
- [Apple: Animations](https://developer.apple.com/documentation/swiftui/animations)
