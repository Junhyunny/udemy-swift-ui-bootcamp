# `@Animatable`과 `@AnimatableIgnored` — 손으로 쓰던 것을 매크로가 대신 쓴다

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
    var isClockWise: Bool  // Boolean은 인터폴레이트 애니메이션 처리가 안된다.
    // ...
}
```

질문은 두 가지다.

1. `@Animatable`의 역할은 무엇이고, 쓰면 어떤 효과를 얻는가. 전달받는 프로퍼티에 **자동으로** 애니메이션을 적용해 주는가
2. `Bool`은 애니메이션할 수 없으니 무시해야 한다 — 그 장치가 `@AnimatableIgnored`인가

## 공부할 내용

### 결론 먼저

**1번의 답은 "반은 맞다"이다.** `@Animatable`은 **애니메이션을 적용해 주는 것이 아니라, `animatableData` 프로퍼티를 대신 작성해 주는 코드 생성기**다.

```text
@Animatable 이 하는 일    →  animatableData 를 컴파일 타임에 합성
@Animatable 이 안 하는 일  →  애니메이션을 촉발 (그건 withAnimation 의 몫)
```

여전히 `withAnimation`으로 감싸야 움직인다. 매크로는 **타이핑을 줄여 줄 뿐**이다.

**2번의 답은 "맞다"이다.** `Bool`은 중간값이 없어 보간이 불가능하고, `@AnimatableIgnored`가 그 프로퍼티를 합성 대상에서 제외한다.

보간의 원리 자체는 [`animatableData` 문서](./098-animatable-data-and-interpolation.md)에 정리되어 있다. 이 문서는 **매크로가 무엇을 만들어 주는지**를 다룬다.

### 공식 정의

> A member and extension macro that, when applied to a struct, class or enum declaration, synthesizes the conformance to `Animatable` and its requirement, the `animatableData` property using the existing animatable properties of the type this macro is applied to.

두 가지를 만든다.

| 붙는 종류 | 만드는 것 |
|---|---|
| extension 매크로 | `extension CircleShape: Animatable { }` — 프로토콜 채택 |
| member 매크로 | `var animatableData { get set }` — 프로토콜 요구사항 |

선언 자체가 그 사실을 말해 준다.

```swift
@attached(extension, conformances: Animatable)
@attached(member, names: named(animatableData))
macro Animatable()
```

매크로가 언제 어떻게 코드를 끼워 넣는지는 [Swift macro와 빌드 파이프라인 문서](./037-swift-macros-and-build-pipeline.md)에 정리되어 있다.

### 무엇이 포함되고 무엇이 빠지는가

공식 문서의 규칙이다.

> The macro inspects every stored property. Properties whose types conform to `VectorArithmetic` or `Animatable` are included in the synthesized `animatableData`. If a property cannot participate, the macro emits an error suggesting you mark it with `AnimatableIgnored()` or conform its type to `VectorArithmetic` or `Animatable`.

| 프로퍼티 | 포함? |
|---|---|
| 저장 프로퍼티이고 타입이 `VectorArithmetic` 또는 `Animatable` | ✓ |
| 저장 프로퍼티인데 보간 불가 타입 | **컴파일 오류** (무시하라고 안내) |
| `@AnimatableIgnored`가 붙음 | ✗ (조용히 제외) |
| 계산 프로퍼티 | ✗ |

문서의 세 가지 Note도 함께 기억할 만하다.

> The `@Animatable` macro will not generate an `Animatable` conformance if the type already conforms to `Animatable`.
>
> It is only possible to attach `@Animatable` to types with properties.
>
> `@Animatable` will not include computed properties in the synthesized `animatableData`.

### 실제로 만들어지는 코드

`-Xfrontend -dump-macro-expansions`로 확장 결과를 직접 볼 수 있다. 질문의 구조를 그대로 넣으면 이런 것이 나온다(식별자를 읽기 쉽게 다듬었다).

```swift
// 1) 프로토콜 채택
extension CircleShape: nonisolated SwiftUICore.Animatable { }

// 2) animatableData 합성
nonisolated var animatableData: some VectorArithmetic {
    get { _animatableData }
    set { _animatableData = inferType(newValue) }
}

// 3) 실제로 묶인 값 — isClockWise 가 빠져 있다
private nonisolated var _animatableData = {
    let radius     = Self[_animatableType: \.radius]
    let startAngle = Self[_animatableType: \.startAngle]
    let endAngle   = Self[_animatableType: \.endAngle]
    return SwiftUICore.AnimatableValues(radius, startAngle, endAngle)
}()
```

세 가지가 눈에 띈다.

- **`AnimatableValues(radius, startAngle, endAngle)`** — 세 값이 평평하게 묶였다. 손으로 썼다면 `AnimatablePair<CGFloat, AnimatablePair<Double, Double>>` 중첩을 감당해야 했다.
- **`isClockWise`가 없다** — `@AnimatableIgnored`가 정확히 제외했다.
- **`nonisolated`가 붙어 있다** — 매크로가 알아서 붙여 준다. 이 키워드의 의미는 [Swift 액터 완전 정복](./153-swift-actor-complete-guide.md)의 `nonisolated` 절에 정리되어 있다.

직접 확인하려면 이렇게 한다.

```bash
xcrun swiftc -typecheck -Xfrontend -dump-macro-expansions \
  -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) \
  -target arm64-apple-ios26.0-simulator MyShape.swift
```

Xcode에서는 매크로 이름을 우클릭하고 **Expand Macro**를 고르면 된다.

### 손으로 쓰면 이만큼이다

같은 결과를 매크로 없이 쓰면 이렇다.

```swift
struct CircleShape: Shape, Animatable {
    var radius: CGFloat
    var startAngle: Double
    var endAngle: Double
    var isClockWise: Bool

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<Double, Double>> {
        get {
            AnimatablePair(radius, AnimatablePair(startAngle, endAngle))
        }
        set {
            radius = newValue.first
            startAngle = newValue.second.first
            endAngle = newValue.second.second
        }
    }
}
```

`newValue.second.first`가 `startAngle`인지 `endAngle`인지 헷갈리기 쉽고, **프로퍼티를 하나 추가할 때마다 중첩이 깊어진다.** 매크로가 없애 주는 것이 정확히 이 고통이다.

### `@AnimatableIgnored`를 빼면 나오는 오류

`@AnimatableIgnored`는 선택이 아니라 **필수**다. 빼면 컴파일이 안 된다.

```swift
@Animatable
struct BadAnim: Shape {
    var radius: CGFloat
    var isClockWise: Bool     // @AnimatableIgnored 없음
}
```

```text
error: Cannot automatically synthesize 'animatableData'.
       (from macro '_SwiftUIAnimatableProperty')
note: Mark this property with '@AnimatableIgnored'.
note: Conform the type of this property to 'Animatable' or 'VectorArithmetic'.
```

오류 메시지가 **해결책 두 가지를 그대로 제시**한다.

| 안내 | 언제 고르나 |
|---|---|
| `@AnimatableIgnored`를 붙여라 | 그 값은 애니메이션할 필요가 없다 → **이 코드의 선택** |
| 타입을 `VectorArithmetic`/`Animatable`에 맞춰라 | 내가 만든 타입이고 보간이 의미 있다 |

`Bool`은 `true`와 `false` 사이에 값이 없으므로 두 번째 길은 애초에 불가능하다. 자세한 이유는 [`animatableData` 문서](./098-animatable-data-and-interpolation.md)의 "그래서 `Bool`은 왜 안 되나"에 있다.

공식 문서의 `@AnimatableIgnored` 정의도 같은 얘기다.

> An accessor macro that marks a property of a type to be excluded from the `animatableData` synthesis.

문서의 예제가 질문의 코드와 판박이다.

```swift
@Animatable
struct CoolShape: Shape {
    var width: CGFloat
    var angle: Angle
    @AnimatableIgnored var isOpaque: Bool
    // ...
}
```

> In the above code, `animatableData` will be synthesized using `width` and `angle` properties of `CoolShape` structure. Since changes to `isOpaque` property cannot be animated, it is annotated with `@AnimatableIgnored`.

### "자동으로 애니메이션이 되나?" — 정확히 하면

질문의 표현을 정밀하게 고치면 이렇다.

```text
[오해]  @Animatable 을 붙이면 프로퍼티가 알아서 애니메이션된다

[실제]  @Animatable 은 "이 프로퍼티들을 보간 대상으로 삼아라"는
        명세(animatableData)를 대신 작성해 준다.
        실제 보간은 withAnimation 이 시작될 때 SwiftUI 가 수행한다.
```

세 가지가 모두 있어야 움직인다.

| 필요한 것 | 이 코드에서 |
|---|---|
| 보간 대상 명세 | `@Animatable`이 합성한 `animatableData` |
| 값의 변화 | `expand.toggle()` → `radius` 등이 바뀜 |
| 애니메이션 촉발 | `withAnimation(.easeIn) { ... }` |

`withAnimation`을 빼면 매크로가 있어도 도형이 툭 바뀐다.

### 버전 — 언제부터 쓸 수 있나

| 심볼 | iOS |
|---|---|
| `Animatable` 프로토콜, `animatableData` | 13 |
| `AnimatablePair` | 13 |
| **`@Animatable` 매크로** | **26** |
| **`@AnimatableIgnored`** | **26** |
| `AnimatableValues` | 26 |

`@Animatable`은 iOS 26부터다. 이 프로젝트의 배포 타깃은 `IPHONEOS_DEPLOYMENT_TARGET = 26.5`라 문제가 없지만, **더 낮은 버전을 지원해야 하면 `AnimatablePair`로 손수 작성**해야 한다. [Swift·iOS 버전 호환성 문서](./074-swift-ios-device-compatibility.md)와 이어진다.

### 매크로를 쓰지 말아야 할 때

매크로는 **저장 프로퍼티를 그대로** 묶는다. 그래서 다음 경우에는 손으로 쓰는 편이 낫다.

- 보간된 값에 **클램핑·정규화**가 필요할 때
- 저장 프로퍼티가 아니라 **파생값**을 보간하고 싶을 때
- 일부 프로퍼티를 **다른 비율로** 움직이고 싶을 때

공식 문서의 표현으로는 "does not correspond one-to-one with a stored property"인 경우다. 예제는 [`animatableData` 문서](./098-animatable-data-and-interpolation.md)의 "직접 쓰는 것이 더 나은 경우"에 있다.

### 곁가지 — `@MainActor`는 필요한가

```swift
@Animatable
@MainActor
struct CircleShape: Shape {
```

이 프로젝트는 빌드 설정이 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`라 **아무것도 안 붙여도 이미 `@MainActor`**다. 즉 이 줄은 중복이고, 오히려 `path(in:)`에 `nonisolated`를 붙여야 하는 원인이 된다. 자세한 내용은 [Swift 액터 완전 정복](./153-swift-actor-complete-guide.md)의 `nonisolated` 절에 정리했다.

### 이 코드에 적용하면

```swift
@Animatable
struct CircleShape: Shape {
    var radius: CGFloat        // → AnimatableValues 에 포함
    var startAngle: Double     // → 포함
    var endAngle: Double       // → 포함
    @AnimatableIgnored
    var isClockWise: Bool      // → 제외 (Bool 은 보간 불가)
}
```

- 매크로가 `extension CircleShape: Animatable`과 `animatableData`를 합성한다
- 합성된 데이터는 `AnimatableValues(radius, startAngle, endAngle)`
- `withAnimation(.easeIn) { expand.toggle() }`이 보간을 촉발한다
- 매 프레임 setter가 세 값을 갱신하고 `path(in:)`이 다시 호출되어 호가 자라며 회전한다
- `isClockWise`는 보간 대상이 아니므로 애니메이션 내내 고정이다

손으로 썼다면 `AnimatablePair` 2중첩 + getter/setter 10여 줄이었을 코드가 **애트리뷰트 두 개**로 줄었다.

## 체크리스트

- [ ] `@Animatable`이 애니메이션을 "적용"하는 게 아니라 `animatableData`를 "작성"한다는 차이를 설명한다.
- [ ] `withAnimation`을 벗기고 매크로만으로는 움직이지 않는 것을 확인한다.
- [ ] Xcode에서 `@Animatable`을 우클릭해 Expand Macro로 생성 코드를 본다.
- [ ] `-dump-macro-expansions`로 명령줄에서도 확장 결과를 뽑아 본다.
- [ ] 확장 결과에 `isClockWise`가 없는 것을 눈으로 확인한다.
- [ ] `@AnimatableIgnored`를 지우고 오류 메시지와 두 가지 안내를 읽는다.
- [ ] 같은 구조를 `AnimatablePair` 2중첩으로 손수 작성해 보고 매크로와 비교한다.
- [ ] 계산 프로퍼티를 추가하고 합성에서 빠지는 것을 확인한다.
- [ ] 이미 `Animatable`을 직접 채택한 타입에 `@Animatable`을 붙여 보고 무슨 일이 생기는지 본다.
- [ ] 배포 타깃을 iOS 25로 낮추면 어떤 오류가 나는지 확인한다.
- [ ] `@MainActor`를 지우고도 빌드되는지 확인한다.

## 공식 참고 자료

- [SwiftUI: Animatable() 매크로](https://developer.apple.com/documentation/swiftui/animatable())
- [SwiftUI: AnimatableIgnored() 매크로](https://developer.apple.com/documentation/swiftui/animatableignored())
- [SwiftUI: Animatable 프로토콜](https://developer.apple.com/documentation/swiftui/animatable)
- [SwiftUI: AnimatableValues](https://developer.apple.com/documentation/swiftui/animatablevalues)
- [SwiftUI: AnimatablePair](https://developer.apple.com/documentation/swiftui/animatablepair)
- [SwiftUI: VectorArithmetic](https://developer.apple.com/documentation/swiftui/vectorarithmetic)
- [The Swift Programming Language: Macros](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/macros/)
- [The Swift Programming Language: Attributes — attached](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/attributes/#attached)
