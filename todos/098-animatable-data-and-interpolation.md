# `animatableData` — SwiftUI가 중간 프레임을 만들어 내는 원리

## 질문이 나온 코드

`chapter-164/chapter-164/ContentView.swift`

```swift
@Animatable
@MainActor
struct CircleShape: Shape {
    var radius: CGFloat
    var startAngle: Double
    var endAngle: Double
    @AnimatableIgnored
    var isClockWise: Bool

    // var animatableData: CGFloat {
    //     get { radius }
    //     set { radius = newValue }
    // }

    // var animatableData: AnimatablePair<CGFloat, Double> {
    //     get { AnimatablePair(radius, startAngle) }
    //     set {
    //         radius = newValue.first
    //         startAngle = newValue.second
    //     }
    // }
}
```

`animatableData`라는 **이름**을 쓰면 자동으로 애니메이션이 되는 것인지, 그 원리가 무엇인지가 질문이다.

## 공부할 내용

### 결론 먼저

**이름 때문이 아니라 프로토콜 요구사항이기 때문**이다. `animatableData`는 `Animatable` 프로토콜이 요구하는 프로퍼티 이름이고, SwiftUI는 그 프로토콜을 통해 값을 읽고 쓴다.

```swift
protocol Animatable {
    associatedtype AnimatableData: VectorArithmetic
    var animatableData: AnimatableData { get set }
}
```

이름을 `myData`로 바꾸면 프로토콜을 만족하지 못해 **아무 일도 일어나지 않는다.** 마법의 이름이 아니라 **약속된 접점**이다.

### 애니메이션이 실제로 벌어지는 순서

공식 문서가 한 문단으로 정확히 설명한다.

> When an animatable value changes inside a `withAnimation(_:_:)` block (or is affected by an `animation(_:value:)` modifier), SwiftUI reads the old and new `animatableData` values, then interpolates between them over successive frames using `VectorArithmetic` operations. The framework calls the `animatableData` setter on each frame, giving your type a chance to update any derived state.

풀어 쓰면 이렇다.

```text
withAnimation { expand.toggle() }
        ↓
뷰가 다시 평가되어 CircleShape(radius: 10 ...) → CircleShape(radius: 50 ...)
        ↓
SwiftUI가 옛 값과 새 값의 animatableData 를 읽는다        ← getter
        ↓  10                              50
        ↓
매 프레임 VectorArithmetic 연산으로 중간값을 계산한다
        ↓  10 → 13.2 → 19.7 → 28.4 → ... → 50
        ↓
매 프레임 animatableData 의 setter 를 호출한다             ← setter
        ↓
setter 안에서 radius 가 갱신된다
        ↓
갱신된 radius 로 path(in:) 이 다시 호출되어 그려진다
```

**핵심은 getter와 setter가 하는 일이 다르다는 것**이다.

| 접근자 | 호출 시점 | 하는 일 |
|---|---|---|
| `get` | 애니메이션 시작 시 2번 (옛 값, 새 값) | "무엇을 보간할지" 알려 줌 |
| `set` | **매 프레임** | 보간된 중간값을 내 프로퍼티에 되돌려 씀 |

```swift
var animatableData: CGFloat {
    get { radius }              // "radius 를 보간해라"
    set { radius = newValue }   // "보간된 값을 radius 에 넣어라"
}
```

setter가 없으면 중간값을 받을 곳이 없어 애니메이션이 되지 않는다. 그래서 `{ get set }`이다.

### 왜 `Shape`에는 원래부터 이게 있나

`Shape`은 `Animatable`을 **상속**한다.

```text
Animatable
    ↑ 상속
  Shape,  InsettableShape,  VisualEffect,  Layout,
  GeometryEffect,  TextRenderer,  AnimatableModifier
```

기본 구현은 `animatableData`가 `EmptyAnimatableData`, 즉 **"보간할 것이 없음"**이다. 그래서 커스텀 `Shape`을 만들고 `withAnimation`으로 감싸도 **기본 상태에서는 도형이 툭 바뀐다.** `animatableData`를 직접 정의(또는 `@Animatable`로 합성)해야 비로소 부드러워진다.

이것이 `.opacity`나 `.offset` 같은 기본 modifier와의 차이다. 그쪽은 SwiftUI가 이미 `Animatable`을 구현해 뒀지만, **내가 만든 `Shape`의 `radius`는 SwiftUI가 알 길이 없다.**

### `VectorArithmetic` — 보간할 수 있는 값의 조건

`AnimatableData`의 타입은 아무거나 될 수 없다. `VectorArithmetic`을 따라야 한다.

> `VectorArithmetic` extends the `AdditiveArithmetic` protocol with scalar multiplication and a way to query the vector magnitude of the value.

요구사항을 보면 왜 그런지 바로 보인다.

```swift
protocol VectorArithmetic: AdditiveArithmetic {
    var magnitudeSquared: Double { get }
    mutating func scale(by rhs: Double)
    func scaled(by rhs: Double) -> Self
    mutating func interpolate(towards other: Self, amount: Double)
    func interpolated(towards other: Self, amount: Double) -> Self
}
```

`AdditiveArithmetic`에서 `+`, `-`, `zero`를 물려받고 여기에 **스칼라 곱**이 더해진다. 보간의 공식이 바로 이것이기 때문이다.

```text
중간값 = 옛값 + (새값 - 옛값) × 진행률

필요한 연산:
  -  (뺄셈)      ← AdditiveArithmetic
  ×  (스칼라 곱) ← VectorArithmetic 의 scale(by:)
  +  (덧셈)      ← AdditiveArithmetic
```

**"더하고 뺄 수 있고, 실수를 곱할 수 있는 값"**만 애니메이션할 수 있다는 뜻이다.

### 그래서 `Bool`은 왜 안 되나

질문의 `@AnimatableIgnored var isClockWise: Bool`이 여기에 걸린다.

`true`와 `false` 사이의 40% 지점은 무엇인가? **그런 값이 없다.** `Bool`에는 `+`도 `-`도 스칼라 곱도 정의할 수 없다.

```text
CGFloat:  10 ────────── 50      중간에 무한히 많은 값이 있다  ✓
Bool:     false ─── ??? ─── true   중간값이 존재하지 않는다   ✗
```

같은 이유로 안 되는 타입들이 있다.

| 타입 | 보간 가능 | 이유 |
|---|---|---|
| `CGFloat`, `Double`, `Float` | ✓ | 표준 라이브러리가 `VectorArithmetic` 채택 |
| `Angle`, `UnitPoint`, `EdgeInsets` | ✓ | SwiftUI가 `Animatable` 채택 |
| `CGPoint`, `CGSize`, `CGRect` | ✓ | SwiftUI가 `Animatable` 채택 |
| `Bool` | ✗ | 중간값이 없음 |
| `String` | ✗ | 중간값이 없음 |
| `Int` | ✗ | 정수라 연속적이지 않음 (`Double`로 바꿔 쓴다) |
| `enum` | ✗ | 중간 case가 없음 |

`Bool`이 바뀌는 효과를 애니메이션하고 싶다면 **`Bool` 자체를 보간하는 게 아니라, 그 값에서 파생된 숫자를 보간**한다.

```swift
// ✗ Bool 을 보간하려는 시도
@AnimatableIgnored var isClockWise: Bool

// ✓ Bool 로 결정되는 숫자를 보간
var direction: CGFloat   // 1.0 또는 -1.0, 그 사이가 의미 있다면
```

`isClockWise`는 호(arc)를 그리는 **방향**이라 중간 상태가 의미 없다. `@AnimatableIgnored`가 올바른 선택이다.

### 여러 값을 한꺼번에 보간하기

`animatableData`는 프로퍼티 **하나**다. 그런데 `radius`와 `startAngle`을 동시에 움직이고 싶다. 그래서 **여러 값을 하나로 묶는 타입**이 있다.

**`AnimatablePair`** (iOS 13+) — 두 개를 묶는다.

```swift
var animatableData: AnimatablePair<CGFloat, Double> {
    get { AnimatablePair(radius, startAngle) }
    set {
        radius = newValue.first
        startAngle = newValue.second
    }
}
```

세 개 이상이면 **중첩**해야 한다. 이게 옛날 방식의 고통이었다.

```swift
var animatableData: AnimatablePair<CGFloat, AnimatablePair<Double, Double>> {
    get { AnimatablePair(radius, AnimatablePair(startAngle, endAngle)) }
    set {
        radius = newValue.first
        startAngle = newValue.second.first
        endAngle = newValue.second.second
    }
}
```

`newValue.second.first` 같은 표기를 읽고 쓰다 보면 순서를 틀리기 십상이다.

**`AnimatableValues`** (iOS 26+) — 여러 개를 평평하게 묶는다.

```swift
var animatableData: AnimatableValues<CGFloat, CGFloat> {
    get { AnimatableValues(amplitude, phase) }
    set {
        amplitude = newValue.value.0
        phase = newValue.value.1
    }
}
```

중첩이 사라지고 `.0`, `.1`로 접근한다. `@Animatable` 매크로가 합성하는 것도 바로 이 `AnimatableValues`다. [`@Animatable` 매크로 문서](./099-animatable-macro.md)에서 실제 확장 결과를 볼 수 있다.

### 직접 쓰는 것이 더 나은 경우

`@Animatable`이 있는데도 손으로 쓰는 이유가 있다. 공식 문서의 설명이다.

> Reach for a handwritten `animatableData` when the interpolated value needs custom logic that does not correspond one-to-one with a stored property, such as normalization, clamping, or driving a derived value.

즉 **저장 프로퍼티와 1:1로 대응하지 않을 때**다.

```swift
struct WaveShape: Shape {
    var amplitude: CGFloat
    var phase: CGFloat
    var maxAmplitude: CGFloat

    var animatableData: AnimatableValues<CGFloat, CGFloat> {
        get { AnimatableValues(amplitude, phase) }
        set {
            amplitude = min(max(newValue.value.0, 0), maxAmplitude)   // ← 클램핑
            phase = newValue.value.1.truncatingRemainder(dividingBy: 2 * .pi)  // ← 정규화
        }
    }
}
```

setter가 **매 프레임 호출된다**는 점을 이용해, 중간값이 들어올 때마다 범위를 자르거나 각도를 0~2π로 되돌린다. 매크로는 값을 그대로 넣기만 하므로 이런 처리를 할 수 없다.

선택 기준을 정리하면 이렇다.

| 상황 | 선택 |
|---|---|
| 저장 프로퍼티를 그대로 보간 | `@Animatable` 매크로 |
| 클램핑·정규화·파생값 계산이 필요 | 손으로 `animatableData` 작성 |
| 일부만 보간 | `@Animatable` + `@AnimatableIgnored` |
| iOS 26 미만 배포 | 손으로 작성 (`AnimatablePair`) |

### 자주 빠지는 함정

**① `withAnimation` 없이는 아무 일도 없다**

`animatableData`는 **보간할 준비**일 뿐이다. 실제로 보간을 촉발하는 것은 `withAnimation`이나 `.animation(_:value:)`다.

```swift
.onTapGesture {
    withAnimation(.easeIn) { expand.toggle() }   // ← 이게 있어야 한다
}
```

[암시적·명시적 애니메이션 문서](./090-implicit-vs-explicit-animation.md), [`animation(_:value:)`의 `value` 문서](./089-animation-value-trigger.md)와 이어진다.

**② `.scaleEffect`와는 결과가 다르다**

질문의 코드에 주석 처리된 줄이 있다.

```swift
// .scaleEffect(expand ? 5 : 1)
```

`scaleEffect`는 **다 그려진 결과를 확대**한다. 선 굵기(`lineWidth: 20`)까지 같이 5배가 된다. 반면 `animatableData`로 `radius`를 키우면 **도형 자체가 다시 그려지므로** 선 굵기는 20으로 유지된다. 같아 보이지만 전혀 다른 결과다.

**③ setter가 매 프레임 호출된다**

setter에 무거운 계산을 넣으면 프레임마다 실행된다. 60fps면 초당 60번이다. 여기서는 대입만 하는 것이 정상이다.

### 이 코드에 적용하면

```swift
@Animatable
struct CircleShape: Shape {
    var radius: CGFloat        // 보간됨
    var startAngle: Double     // 보간됨
    var endAngle: Double       // 보간됨
    @AnimatableIgnored
    var isClockWise: Bool      // 제외
}
```

탭하면 이런 일이 벌어진다.

```text
withAnimation(.easeIn) { expand.toggle() }
        ↓
radius:     10 → 50
startAngle:  0 → 180
endAngle:  180 → 360
        ↓
세 값이 AnimatableValues 로 묶여 함께 보간된다
        ↓
매 프레임 setter → radius/startAngle/endAngle 갱신
        ↓
매 프레임 path(in:) 재호출 → 호가 자라면서 회전한다
```

`isClockWise`는 보간에서 빠졌으므로 애니메이션 내내 `true`로 고정된다.

주석 처리된 두 후보와 비교하면 이렇다.

| 방식 | 보간되는 값 | 결과 |
|---|---|---|
| `animatableData: CGFloat` | `radius`만 | 크기만 자람, 각도는 툭 바뀜 |
| `animatableData: AnimatablePair<CGFloat, Double>` | `radius`, `startAngle` | `endAngle`만 툭 바뀜 |
| `@Animatable` (현재) | 셋 다 | 전부 부드럽게 |

## 체크리스트

- [ ] `animatableData`가 마법의 이름이 아니라 프로토콜 요구사항임을 설명한다.
- [ ] getter는 2번, setter는 매 프레임 호출된다는 것을 `print`로 확인한다.
- [ ] setter를 지우고(`get`만 남기고) 컴파일 오류를 확인한다.
- [ ] `Shape`이 `Animatable`을 상속한다는 것을 문서에서 확인한다.
- [ ] `animatableData`를 아예 없애고 도형이 툭 바뀌는 것을 본다.
- [ ] `VectorArithmetic`의 요구사항과 보간 공식(`옛값 + (새값-옛값)×진행률`)을 연결해 설명한다.
- [ ] `Bool`을 `animatableData`에 넣으려 시도하고 오류를 읽는다.
- [ ] `animatableData: CGFloat` 버전으로 바꿔 `radius`만 애니메이션되는 것을 확인한다.
- [ ] `AnimatablePair`를 3중첩으로 직접 써 보고 `@Animatable`과 비교한다.
- [ ] setter에서 `radius`를 클램핑해 커스텀 로직이 매 프레임 도는 것을 확인한다.
- [ ] `.scaleEffect(expand ? 5 : 1)` 주석을 풀고 선 굵기 차이를 관찰한다.
- [ ] `withAnimation`을 벗기고 애니메이션이 사라지는 것을 확인한다.

## 공식 참고 자료

- [SwiftUI: Animatable](https://developer.apple.com/documentation/swiftui/animatable)
- [SwiftUI: Animatable — animatableData](https://developer.apple.com/documentation/swiftui/animatable/animatabledata-6nydg)
- [SwiftUI: VectorArithmetic](https://developer.apple.com/documentation/swiftui/vectorarithmetic)
- [SwiftUI: AnimatablePair](https://developer.apple.com/documentation/swiftui/animatablepair)
- [SwiftUI: AnimatableValues](https://developer.apple.com/documentation/swiftui/animatablevalues)
- [SwiftUI: EmptyAnimatableData](https://developer.apple.com/documentation/swiftui/emptyanimatabledata)
- [SwiftUI: Shape](https://developer.apple.com/documentation/swiftui/shape)
- [SwiftUI: Shape — path(in:)](https://developer.apple.com/documentation/swiftui/shape/path(in:))
- [SwiftUI: withAnimation(_:_:)](https://developer.apple.com/documentation/swiftui/withanimation(_:_:))
- [Swift Standard Library: AdditiveArithmetic](https://developer.apple.com/documentation/swift/additivearithmetic)
