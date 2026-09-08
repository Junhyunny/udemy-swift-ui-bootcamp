# 애니메이션 API 세 가지 비교 — `animation`, `withAnimation`, `phaseAnimator`

개별 문서가 이미 있다. [암시적 애니메이션과 `withAnimation`의 차이](./implicit-vs-explicit-animation.md), [`animation(_:value:)`의 `value`가 필요한 이유](./animation-value-trigger.md), [`phaseAnimator`의 파라미터](./phase-animator-parameters-and-phase-types.md). 이 문서는 **셋을 나란히 놓고 언제 무엇을 고를지**를 정리한다.

## 질문이 나온 코드

`chapter-54/chapter-54/ContentView.swift`

```swift
VStack(spacing: 0) {
    Rectangle()
        .frame(width: 1, height: 150)
    Circle()
        .fill(.brown.gradient)
        .frame(height: 25)
}
.phaseAnimator([45.0, -45.0]) { view, phase in
    view.rotationEffect(
        .degrees(phase),
        anchor: .top
    )
} animation: { phase in
    switch phase {
    case -45.0:
        return .snappy
    default:
        return .spring(dampingFraction: 0.1)
    }
}
```

## 공부할 내용

### 먼저 — 왜 세 가지나 있는가

Apple은 애니메이션을 추가하는 방법을 이렇게 안내한다.

> To avoid abrupt visual transitions when the state changes, add animation in one of the following ways:
> - Animate all of the visual changes for a state change by changing the state inside a call to the `withAnimation(_:_:)` global function.
> - Add animation to a particular view when a specific value changes by applying the `animation(_:value:)` view modifier to the view.
> - Animate changes to a `Binding` by using the binding's `animation(_:)` method.

여기까지가 **상태 변화 기반** 애니메이션이다. `phaseAnimator`는 다른 범주에 속한다.

> A phase animator allows you to define an animation as a collection of discrete steps called **phases**. The animator cycles through these phases to create a visual transition.

즉 셋은 경쟁 관계가 아니라 **다루는 문제의 종류가 다르다.**

| | 다루는 문제 |
| --- | --- |
| `animation(_:value:)` | 상태 A → B 전환 한 번 |
| `withAnimation` | 상태 변경 **동작**을 감싸기 |
| `phaseAnimator` | 여러 **단계**를 순환 |

### 한눈에 비교

| | `animation(_:value:)` | `withAnimation` | `phaseAnimator` |
| --- | --- | --- | --- |
| 형태 | view modifier | 전역 함수 | view modifier |
| 붙는 곳 | 뷰 | 상태 변경 코드 | 뷰 |
| 애니메이션 개시 | 감시값 변화 | 클로저 실행 | trigger 변화 또는 자동 |
| 적용 범위 | **그 뷰와 하위** | 그 변경에 영향받는 **모든 뷰** | 그 뷰와 하위 |
| 단계 수 | 2 (A↔B) | 2 (A↔B) | **N개** |
| 단계별 곡선 | 하나 | 하나 | **단계마다 지정** |
| 자동 반복 | `repeatForever`로 가능 | 불가 | **`trigger` 생략 시 기본** |
| 최소 버전 | iOS 13 | iOS 13 | **iOS 17** |

### ① `animation(_:value:)` — 뷰에 규칙을 붙인다

```swift
func animation<V>(_ animation: Animation?, value: V) -> some View where V : Equatable
```

```swift
Circle()
    .scaleEffect(scale)
    .animation(.easeIn, value: scale)
```

**"이 뷰는 `scale`이 바뀌면 `.easeIn`으로 움직인다"** 는 규칙을 선언한다. 누가 `scale`을 바꾸든 상관없다.

**언제 쓰나**

- 특정 뷰 하나의 특정 값에만 애니메이션을 걸고 싶을 때
- 재사용 컴포넌트 안에서 자기 애니메이션을 스스로 정의할 때 — 쓰는 쪽이 신경 쓰지 않아도 된다
- 상태를 바꾸는 코드가 여러 군데라 한곳에서 감쌀 수 없을 때

**좋은 점**

- 애니메이션 규칙이 **뷰 정의에 붙어 있어** 응집도가 높다
- 상태 변경 코드를 건드리지 않는다
- 범위가 좁아 의도치 않은 뷰가 함께 움직이지 않는다

**나쁜 점**

- `value:`를 명시해야 한다. 무엇을 감시할지 매번 골라야 한다
- 여러 값에 각각 다른 곡선을 주려면 modifier를 여러 번 쌓아야 한다
- 한 상태 변경이 여러 뷰에 영향을 줄 때 각 뷰마다 붙여야 한다
- `value:` 없는 `animation(_:)`는 **deprecated**다. 범위가 불명확해 예측 불가능한 애니메이션을 유발했다

`value:`가 왜 필요한지는 [별도 문서](./animation-value-trigger.md)에 정리했다.

### ② `withAnimation` — 상태 변경을 감싼다

```swift
func withAnimation<Result>(_ animation: Animation? = .default, _ body: () throws -> Result) rethrows -> Result
```

```swift
withAnimation(.bouncy) {
    offset = -40.0
}
```

동작 원리가 문서에 명시되어 있다.

> This function sets the given `Animation` as the `animation` property of the thread's current `Transaction`.

**트랜잭션에 애니메이션을 심는다.** 그래서 그 클로저 안에서 일어난 상태 변경에 **영향받는 모든 뷰**가 함께 움직인다.

**언제 쓰나**

- 하나의 상태 변경이 **여러 뷰**를 동시에 바꿀 때
- 사용자 액션에 대한 반응처럼 **언제 애니메이션할지가 명확**할 때
- 같은 상태를 어떤 경우엔 애니메이션하고 어떤 경우엔 즉시 바꾸고 싶을 때

```swift
// 사용자가 누르면 애니메이션
Button("보이기") { withAnimation { isVisible = true } }

// 초기화는 즉시
func reset() { isVisible = false }
```

이 유연성은 `animation(_:value:)`로는 얻을 수 없다.

**완료 콜백**도 쓸 수 있다.

```swift
withAnimation(.bouncy) {
    offset = -40.0
} completion: {
    withAnimation {
        offset = 0.0
    }
}
```

**좋은 점**

- 적용 범위가 넓어 **여러 뷰를 한 번에** 조율한다
- 애니메이션 여부를 **호출 시점에 결정**할 수 있다
- 완료 시점을 알 수 있다 (`withAnimation(_:completionCriteria:_:completion:)`)

**나쁜 점**

- 상태를 바꾸는 **모든 곳**에 감싸야 한다. 하나라도 빠뜨리면 그 경로만 애니메이션되지 않는다
- 범위가 넓어 **의도하지 않은 뷰까지** 움직일 수 있다
- 애니메이션 규칙이 뷰가 아니라 로직 쪽에 흩어진다
- 재사용 컴포넌트를 만들 때는 쓰는 쪽에 책임이 넘어간다

### ③ `phaseAnimator` — 여러 단계를 순환한다

앞의 둘로는 다루기 힘든 문제가 있다. Apple의 아티클이 그 한계를 단계적으로 보여 준다.

한 단계짜리는 `withAnimation`으로 충분하다.

```swift
.onTapGesture {
    withAnimation(.bouncy) {
        offset = -40.0
    }
}
```

두 단계가 되면 completion을 중첩해야 한다.

```swift
withAnimation(.bouncy) {
    offset = -40.0
} completion: {
    withAnimation {
        offset = 0.0
    }
}
```

세 단계, 네 단계로 늘어나면 중첩이 감당이 안 된다. `phaseAnimator`가 이 문제를 푼다.

```swift
.phaseAnimator([false, true], trigger: likeCount) { content, phase in
    content.offset(y: phase ? -40.0 : 0.0)
} animation: { phase in
    phase ? .bouncy : .default
}
```

**언제 쓰나**

- 애니메이션이 **세 단계 이상**을 거칠 때
- 단계마다 **다른 곡선**이 필요할 때 — 이 예제가 그렇다
- **자동 반복**이 필요할 때 (로딩, 펄스, 주의 환기)
- 상태 변수를 늘리지 않고 시각 효과만 순환시키고 싶을 때

**좋은 점**

- 단계가 늘어도 코드가 **평평하게** 유지된다. completion 중첩이 없다
- 단계마다 곡선을 다르게 줄 수 있다
- `trigger`를 빼면 자동 반복이 공짜로 된다
- `enum`으로 단계를 정의하면 여러 속성을 함께 관리할 수 있다

Apple이 권하는 방식이 그것이다.

```swift
private enum AnimationPhase: CaseIterable {
    case initial
    case move
    case scale

    var verticalOffset: Double {
        switch self {
        case .initial: 0
        case .move, .scale: -64
        }
    }
}
```

**나쁜 점**

- **iOS 17 이상**이다. 하위 호환이 필요하면 쓸 수 없다
- 단계가 **선형 순환**이라 임의의 단계로 점프할 수 없다
- 각 단계의 **지속 시간을 직접 지정할 수 없다.** 곡선이 결정한다 — 정밀한 타이밍이 필요하면 `keyframeAnimator`
- 상태와 시각 효과가 분리되어 있어, 현재 어느 단계인지 코드 밖에서 알기 어렵다

### 성능

정직하게 말하면, **Apple이 세 API의 성능을 직접 비교한 공식 자료는 없다.** 다만 문서에서 확인되는 사실과 구조에서 추론되는 것을 구분해 정리할 수 있다.

**문서로 확인되는 것**

`keyframeAnimator`에는 명시적 경고가 있다.

> Note that the content closure will be updated on **every frame** while animating, so avoid performing any expensive operations directly within content.

`phaseAnimator`에는 이런 경고가 없다. **단계가 바뀔 때만** content 클로저가 재평가되기 때문이다. 이것이 두 API의 실질적 비용 차이다.

**구조에서 나오는 차이**

| | 클로저 호출 빈도 | 비교 비용 |
| --- | --- | --- |
| `animation(_:value:)` | 상태 변경 시 | `value`의 `Equatable` 비교 |
| `withAnimation` | 상태 변경 시 | 없음 (트랜잭션에 심음) |
| `phaseAnimator` | **단계 전환 시** | `trigger`의 `Equatable` 비교 |
| `keyframeAnimator` | **매 프레임** | — |

셋 다 실제 보간과 렌더링은 SwiftUI 내부에서 처리하므로, **애니메이션 자체의 비용은 세 방법이 크게 다르지 않다.**

**실제로 성능을 좌우하는 것**

API 선택보다 다음이 훨씬 큰 영향을 준다.

- **애니메이션되는 뷰의 개수와 복잡도.** 무거운 뷰 계층을 움직이면 어느 API를 쓰든 느리다
- **`withAnimation`의 범위.** 클로저 안의 상태 변경이 영향을 주는 뷰가 많을수록 재렌더링이 커진다. 범위를 좁히는 것이 최적화다
- **어떤 효과인가.** `opacity`, `scaleEffect`, `offset`은 GPU에서 처리되어 저렴하다. 레이아웃을 다시 계산하게 만드는 `frame` 변경은 비싸다
- **`blur`, `shadow` 같은 효과.** 매 프레임 다시 그려야 해서 비싸다
- **불필요한 body 재평가.** 애니메이션 도중 `@State`가 바뀌어 body가 다시 도는 구조라면 그게 병목이다

**실무 지침**

- 애니메이션이 버벅이면 API를 바꾸기 전에 **무엇이 움직이는지**를 먼저 본다
- 레이아웃을 바꾸는 애니메이션(`frame`)보다 그리기만 바꾸는 것(`scaleEffect`)을 택한다
- 접근성 설정을 존중한다 — [`\.accessibilityReduceMotion`](./environment-property-wrapper.md)

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

.phaseAnimator(reduceMotion ? [0.0] : [45.0, -45.0]) { ... }
```

### 이 예제 분석

```swift
.phaseAnimator([45.0, -45.0]) { view, phase in
    view.rotationEffect(.degrees(phase), anchor: .top)
} animation: { phase in
    switch phase {
    case -45.0: return .snappy
    default:    return .spring(dampingFraction: 0.1)
    }
}
```

**`phaseAnimator`가 맞는 선택인 이유가 셋 있다.**

**① `trigger`가 없다 — 자동 반복이다**

`trigger:` 인자가 빠져 있으므로 사용자 입력 없이 계속 순환한다. 진자가 좌우로 흔들리는 효과다.

> Right away, the modifier provides its content closure with the value of the second phase. As soon as the animation completes, the procedure repeats using successive phases until reaching the last phase, at which point the modifier loops back to the first phase.

같은 것을 `withAnimation`으로 만들려면 `onAppear` + completion 재귀나 `Timer`가 필요하다. `animation(_:value:)` + `repeatForever`로도 가능하지만 단계별 곡선을 줄 수 없다.

**② 단계마다 곡선이 다르다**

이게 결정적이다.

| 단계 | 곡선 | 효과 |
| --- | --- | --- |
| `-45.0` | `.snappy` | 빠르고 깔끔하게 |
| `45.0` | `.spring(dampingFraction: 0.1)` | **댐핑이 0.1로 매우 낮아 크게 출렁인다** |

`dampingFraction`이 낮을수록 진동이 오래 남는다. 0.1이면 목표 각도를 지나쳐 여러 번 왕복한다. 진자의 물리적 느낌을 흉내 내는 설정이다.

**`animation(_:value:)`나 `withAnimation`은 곡선을 하나만 지정한다.** 방향에 따라 다른 느낌을 주려면 상태를 따로 두고 분기해야 하는데, `phaseAnimator`는 그것을 클로저 하나로 해결한다.

**③ 상태 변수가 필요 없다**

`ContentView`에 `@State`가 하나도 없다. 시각 효과만 순환하면 되고 앱 로직이 알아야 할 상태가 아니기 때문이다. `withAnimation` 방식이었다면 `@State private var angle`이 필요했을 것이다.

**`anchor: .top`도 눈여겨볼 부분이다.** 회전축을 위쪽 끝에 두어 진자처럼 매달린 형태가 된다. 기본값 `.center`였다면 막대 중앙을 축으로 돌아 전혀 다른 움직임이 된다.

주석 처리된 `.easeInOut.speed(0.5)`는 단계 구분 없이 하나의 곡선을 쓰는 버전이다. 되살려 보면 단계별 곡선의 차이가 체감된다.

### 선택 기준

```text
애니메이션이 필요하다
│
├─ 단계가 3개 이상이거나, 단계마다 다른 곡선이 필요한가?
│    └─ 예 → phaseAnimator
│         └─ 각 단계의 지속 시간까지 정밀 제어? → keyframeAnimator
│
├─ 자동으로 계속 반복되어야 하는가?
│    └─ 예 → phaseAnimator (trigger 생략)
│
├─ 하나의 상태 변경이 여러 뷰를 동시에 바꾸는가?
│    └─ 예 → withAnimation
│
├─ 같은 상태를 때에 따라 애니메이션할지 말지 정해야 하는가?
│    └─ 예 → withAnimation
│
└─ 특정 뷰의 특정 값에만 걸면 되는가?
     └─ 예 → animation(_:value:)
```

**섞어 쓸 수 있다.** 한 화면에서 컴포넌트는 `animation(_:value:)`로 자기 애니메이션을 갖고, 화면 전환은 `withAnimation`으로 조율하고, 로딩 인디케이터는 `phaseAnimator`로 도는 구성이 자연스럽다.

### 그 외의 선택지들

Apple의 Animations 문서에는 더 있다.

| API | 용도 |
| --- | --- |
| `Binding.animation(_:)` | 바인딩 변화에 애니메이션 |
| `animation(_:body:)` | 지정한 modifier에만 애니메이션 적용 |
| `keyframeAnimator` | 시간축 기반 정밀 제어 |
| `transition(_:)` | 뷰 추가·제거 시 전환 |
| `matchedGeometryEffect` | 두 뷰 사이 형태 연결 |
| `TimelineView` | 스케줄에 따른 갱신 |
| `CustomAnimation` | 직접 만드는 곡선 |

`animation(_:body:)`는 범위를 좁히는 데 유용하다.

```swift
MyView(isActive: isActive)
    .animation(.easeInOut) { content in
        content.opacity(isActive ? 1.0 : 0.0)
    }
```

> Any modifiers applied to the content of body will be applied to this view, and the animation will only be used on the modifiers defined in the body.

`opacity`만 `.easeInOut`으로 움직이고 나머지는 영향받지 않는다.

## 학습 체크리스트

- [ ] `animation:` 클로저를 지우고 기본 곡선만 쓸 때와 비교한다.
- [ ] 주석 처리된 `.easeInOut.speed(0.5)`를 되살려 단계별 곡선과 비교한다.
- [ ] `dampingFraction`을 0.1에서 0.9로 바꿔 출렁임이 사라지는 것을 확인한다.
- [ ] `anchor: .top`을 `.center`로 바꿔 회전축의 차이를 본다.
- [ ] `trigger:`를 추가하고 `onTapGesture`로 수동 전환되게 바꿔 본다.
- [ ] 같은 진자를 `withAnimation` + `onAppear` 재귀로 구현해 보고 코드량을 비교한다.
- [ ] 같은 진자를 `animation(_:value:)` + `repeatForever`로 만들어 보고 단계별 곡선이 불가능함을 확인한다.
- [ ] `phases`에 단계를 하나 더 추가해 세 단계 순환을 만든다.
- [ ] `withAnimation` 안에서 두 개의 `@State`를 바꿔 두 뷰가 함께 움직이는 것을 확인한다.
- [ ] 같은 것을 `animation(_:value:)`로 하려면 어떻게 해야 하는지 비교한다.
- [ ] 버튼에서는 `withAnimation`, 초기화에서는 그냥 대입해 같은 상태가 다르게 동작하는 것을 확인한다.
- [ ] `animation(_:body:)`로 특정 modifier에만 애니메이션을 걸어 본다.
- [ ] `frame`을 애니메이션하는 경우와 `scaleEffect`를 쓰는 경우의 부드러움을 비교한다.
- [ ] `\.accessibilityReduceMotion`을 읽어 애니메이션을 끄는 분기를 넣는다.
- [ ] Instruments로 애니메이션 중 프레임 드랍이 있는지 측정한다.

## 공식 참고 자료

- [Apple: Animations](https://developer.apple.com/documentation/swiftui/animations)
- [Apple: Controlling the timing and movements of your animations](https://developer.apple.com/documentation/swiftui/controlling-the-timing-and-movements-of-your-animations)
- [Apple: withAnimation(_:_:)](https://developer.apple.com/documentation/swiftui/withanimation(_:_:))
- [Apple: withAnimation(_:completionCriteria:_:completion:)](https://developer.apple.com/documentation/swiftui/withanimation(_:completioncriteria:_:completion:))
- [Apple: view.animation(_:value:)](https://developer.apple.com/documentation/swiftui/view/animation(_:value:))
- [Apple: view.animation(_:body:)](https://developer.apple.com/documentation/swiftui/view/animation(_:body:))
- [Apple: view.phaseAnimator(_:content:animation:)](https://developer.apple.com/documentation/swiftui/view/phaseanimator(_:content:animation:))
- [Apple: view.phaseAnimator(_:trigger:content:animation:)](https://developer.apple.com/documentation/swiftui/view/phaseanimator(_:trigger:content:animation:))
- [Apple: view.keyframeAnimator(initialValue:trigger:content:keyframes:)](https://developer.apple.com/documentation/swiftui/view/keyframeanimator(initialvalue:trigger:content:keyframes:))
- [Apple: Animation](https://developer.apple.com/documentation/swiftui/animation)
- [Apple: Transaction](https://developer.apple.com/documentation/swiftui/transaction)
- [Apple: Spring](https://developer.apple.com/documentation/swiftui/spring)
- [Apple HIG: Motion](https://developer.apple.com/design/human-interface-guidelines/motion)
