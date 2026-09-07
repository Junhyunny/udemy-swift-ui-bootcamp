# `CG`로 시작하는 타입들 — `CGFloat`은 `Float`과 무엇이 다른가

Swift의 기본 숫자 타입 자체는 [Swift의 기본 타입과 비교 방법](./swift-fundamental-types-and-comparison.md)에서 다뤘다. 이 문서는 **`CG` 접두사가 붙은 타입군**과 `CGFloat`의 정체를 파고든다.

## 질문이 나온 코드

`chapter-45/chapter-45/ContentView.swift`

```swift
let columns = 3
let spacing: CGFloat = 10

var body: some View {
    GeometryReader { geometry in
        ScrollView {
            let itemWidth = (geometry.size.width - (spacing * CGFloat(columns - 1))) / CGFloat(columns)
            // ...
        }
    }
}

func gridItems(width: CGFloat) -> [GridItem] { /* ... */ }
```

`spacing`은 `CGFloat`으로 선언했고, `columns`는 `Int`라서 `CGFloat(...)`으로 감싸야 한다.

## 공부할 내용

### 결론 먼저

- `CG`는 **Core Graphics** 프레임워크의 접두사다. Objective-C/C 시절 네임스페이스가 없어 접두사로 소속을 표시한 관례가 남은 것이다.
- `CGFloat`은 **아키텍처에 따라 크기가 달라지는** 부동소수점 타입이다. 64비트에서는 `Double`, 32비트에서는 `Float`과 같다.
- 오늘날 실제 기기는 모두 64비트이므로 `CGFloat == Double`이라고 봐도 된다.
- Swift 5.5부터 `CGFloat`과 `Double`은 **암시적으로 상호 변환**된다. 그래서 대부분의 경우 신경 쓰지 않아도 된다.
- 다만 `Int`는 그 대상이 아니다. 예제 코드가 `CGFloat(columns)`로 명시적 변환을 하는 이유가 여기에 있다.
- 질문의 "CG 클래스들" 중 기하 타입들은 **class가 아니라 struct**다. 이 구분이 중요하다.

### `CG`는 무슨 뜻인가

Apple의 Core Graphics 프레임워크 문서는 이렇게 설명한다.

> The Core Graphics framework is based on the Quartz advanced drawing engine. It provides low-level, lightweight 2D rendering with unmatched output fidelity. You use this framework to handle path-based drawing, transformations, color management, offscreen rendering, patterns, gradients and shadings, image data management, image creation, and image masking, as well as PDF document creation, display, and parsing.

즉 `CG`가 붙은 타입은 **2D 그래픽스 렌더링을 위한 저수준 타입**이라는 뜻이다. SwiftUI는 이 위에 얹혀 있고, 그래서 `size`, `frame`, `offset` 같은 기하 값이 모두 `CG` 타입으로 나온다.

Apple 프레임워크의 접두사 관례를 같이 알아 두면 타입 이름만 보고 출신을 알 수 있다.

| 접두사 | 프레임워크 | 예 |
| --- | --- | --- |
| `CF` | Core Foundation | `CFString`, `CFArray` |
| `CG` | Core Graphics | `CGFloat`, `CGRect` |
| `CA` | Core Animation | `CALayer`, `CAAnimation` |
| `CI` | Core Image | `CIImage`, `CIFilter` |
| `CL` | Core Location | `CLLocation` |
| `NS` | Foundation (구 NeXTSTEP) | `NSString`, `NSObject` |
| `UI` | UIKit | `UIView`, `UIColor` |
| `SK` | SpriteKit | `SKScene` |

Swift는 모듈 단위 네임스페이스가 있어 새 타입에는 접두사를 붙이지 않는다. SwiftUI 타입이 `SUView`가 아니라 그냥 `View`인 이유다. `CG*`는 C 시대 API가 그대로 이어져 온 유산이다.

### `CGFloat`은 `Float`과 무엇이 다른가

Apple 문서의 정의가 핵심이다.

> The size and precision of this type depend on the CPU architecture. When you build for a 64-bit CPU, the `CGFloat` type is a 64-bit, IEEE double-precision floating point type, equivalent to the `Double` type. When you build for a 32-bit CPU, the `CGFloat` type is a 32-bit, IEEE single-precision floating point type, equivalent to the `Float` type.

`CGFloat.NativeType`이 이를 그대로 드러낸다.

```swift
typealias NativeType = Double   // 64비트 아키텍처
```

> The native type used to store the `CGFloat`, which is `Float` on 32-bit architectures and `Double` on 64-bit architectures.

비교하면 이렇게 정리된다.

| 타입 | 비트 수 | 정밀도 | 성격 |
| --- | --- | --- | --- |
| `Float` (`Float32`) | 32 | 단정밀도 | 고정 |
| `Double` (`Float64`) | 64 | 배정밀도 | 고정 |
| `CGFloat` | 32 또는 64 | 아키텍처 의존 | **가변** |

핵심 차이는 값의 크기가 아니라 **"고정이냐 아키텍처 의존이냐"** 다. `CGFloat`은 독립적인 새 숫자 타입이 아니라, 플랫폼에 맞는 부동소수점 타입을 골라 주는 래퍼에 가깝다.

Swift 표준 라이브러리의 권장 기준은 별개로 명확하다.

> If you don't need to specify an exact size, use `Double`. Otherwise, use the type that includes the needed size in its name, such as `Float16` or `Float80`. Following common terminology for floating-point math, `Float` uses 32 bits and `Double` uses 64 bits. (…) For example, graphics code often uses `Float` to match the GPU's fastest data type.

즉 순수 Swift 코드에서는 `Double`이 기본이고, `Float`은 GPU 데이터 타입에 맞출 때처럼 크기를 정확히 지정해야 할 때 쓴다. `CGFloat`은 **Apple 그래픽스 API와 맞물릴 때** 쓰는 타입이다.

### Swift 5.5부터 `CGFloat`과 `Double`은 섞어 쓸 수 있다

과거에는 `CGFloat(someDouble)` 같은 변환 코드가 SwiftUI 코드를 뒤덮었다. Swift Evolution SE-0307이 이를 해결했다.

제안서의 동기는 이렇다.

> 64-bit devices are now the norm, and even on 32-bit `Double` is now often the better choice for calculations.

그래서 다음 코드가 지금은 그냥 컴파일된다.

```swift
let ratio: Double = 0.6
Rectangle()
    .frame(height: geometry.size.height * ratio)   // CGFloat * Double, OK
```

변환 규칙에는 정밀도 손실을 줄이기 위한 우선순위가 있다.

- `Double is always preferred over CGFloat where possible, in order to limit possibility of ambiguities`
- `Any number of widening conversions (CGFloat → Double) is preferred over a single narrowing one (Double → CGFloat)`

즉 컴파일러는 가능한 한 넓은 쪽(`Double`)으로 올려 계산하고, 좁히는 변환은 최대한 늦게 한 번만 한다.

**주의할 예외**가 있다.

- 컬렉션은 자동 변환되지 않는다. `[Double]`을 `[CGFloat]` 자리에 넘길 수 없다.
  > Arrays, sets, or dictionaries containing `CGFloat` or `Double` keys/values have to be explicitly converted
- `CGFloat(...)` 이니셜라이저를 **직접 호출**하는 경우는 암시적 변환 대상이 아니다.
- `as` 캐스팅에도 적용되지 않는다.

### 그런데 왜 예제는 `CGFloat(columns)`가 필요한가

SE-0307이 다루는 건 **`Double` ↔ `CGFloat`** 뿐이다. `Int`는 포함되지 않는다. Swift는 정수와 부동소수점 사이의 암시적 변환을 **의도적으로 허용하지 않는다.**

```swift
let columns = 3                 // Int (타입 추론)
let spacing: CGFloat = 10       // CGFloat

spacing * columns               // ❌ 컴파일 에러
spacing * CGFloat(columns)      // ✅ 명시적 변환
```

그래서 예제의 이 줄이 필요하다.

```swift
let itemWidth = (geometry.size.width - (spacing * CGFloat(columns - 1))) / CGFloat(columns)
```

`geometry.size.width`가 `CGFloat`이므로 나머지 항도 `CGFloat`으로 맞춰 준 것이다.

한편 `let spacing: CGFloat = 10`에서 정수 리터럴 `10`이 그대로 들어가는 건 `CGFloat`이 `ExpressibleByIntegerLiteral`을 만족하기 때문이다. **리터럴**은 타입이 정해지기 전이라 문맥에 맞춰지고, **이미 타입이 정해진 변수**는 변환이 필요하다. 이 둘의 차이를 구분하는 게 중요하다.

`columns`를 아예 `CGFloat`으로 선언해 변환을 없앨 수도 있다. 하지만 "열 개수"는 개념상 정수이므로, `Int`로 두고 계산 지점에서만 변환하는 현재 코드가 의도를 더 잘 드러낸다.

### 어떤 `CG` 타입들이 있는가 — struct와 class를 구분해서

질문의 "CG 클래스들"이라는 표현을 정확히 하면, `CG` 타입은 두 부류로 갈린다. [`struct`와 `class`](./struct-vs-class.md)의 차이가 그대로 적용된다.

**값 타입 (struct) — 기하 데이터**

| 타입 | 용도 | 주요 멤버 |
| --- | --- | --- |
| `CGFloat` | 좌표·크기 스칼라 | `native`, `bitPattern` |
| `CGPoint` | 한 점 | `x`, `y`, `.zero` |
| `CGSize` | 너비·높이 | `width`, `height`, `.zero` |
| `CGRect` | 위치 + 크기 | `origin`, `size`, `minX`, `midY`, `maxX`, `isEmpty` |
| `CGVector` | 방향과 크기 | `dx`, `dy` |
| `CGAffineTransform` | 2D 아핀 변환 | 이동·회전·스케일 행렬 |

이들은 모두 `struct`, 즉 **값 타입**이다. 복사하면 독립된 값이 되고, `let`으로 잡으면 내부 프로퍼티도 바꿀 수 없다. SwiftUI에서 매일 만나는 타입들이 여기 속한다.

```swift
let frame = CGRect(x: 10, y: 20, width: 100, height: 50)
frame.midX          // 60.0
frame.size          // CGSize(width: 100, height: 50)
frame.origin        // CGPoint(x: 10, y: 20)
frame.isEmpty       // false
```

`CGRect`는 계산 편의 프로퍼티와 메서드가 풍부해서 직접 산술할 필요가 거의 없다.

```swift
let a = CGRect(x: 0, y: 0, width: 100, height: 100)
let b = CGRect(x: 50, y: 50, width: 100, height: 100)
a.intersection(b)   // 겹치는 영역
a.union(b)          // 둘을 모두 포함하는 영역
a.contains(CGPoint(x: 10, y: 10))
a.insetBy(dx: 10, dy: 10)
a.integral          // 픽셀 경계에 맞춘 정수 사각형
```

앞서 정리한 [좌표 공간 문서](./coordinate-space-local-global-named.md)의 `frame(in:)`이 돌려주는 것도 `CGRect`, `bounds(of:)`도 `CGRect?`다.

**참조 타입 (class) — 그래픽스 객체**

| 타입 | 용도 |
| --- | --- |
| `CGContext` | 그리기 대상 컨텍스트 |
| `CGImage` | 비트맵 이미지 |
| `CGPath` / `CGMutablePath` | 경로 |
| `CGColor` | 색 |
| `CGColorSpace` | 색 공간 |
| `CGFont` | 폰트 |
| `CGLayer` | 재사용 가능한 그리기 레이어 |
| `CGGradient` / `CGShading` | 그라디언트 |
| `CGPattern` | 패턴 |
| `CGPDFDocument` | PDF 문서 |

이들은 실제 리소스를 소유하는 객체이므로 참조 타입이다. 이름은 같은 `CG` 접두사지만 성격이 전혀 다르다.

```text
CG 타입
├─ 값 타입 (struct) — 숫자와 기하 데이터
│  CGFloat, CGPoint, CGSize, CGRect, CGVector, CGAffineTransform
│  → SwiftUI에서 항상 만난다
└─ 참조 타입 (class) — 그래픽스 리소스
   CGContext, CGImage, CGPath, CGColor, CGFont, ...
   → 저수준 드로잉이 필요할 때만 만난다
```

### 언제 쓰고, 언제 쓰면 안 되는가

**`CGFloat`을 쓸 때**

- SwiftUI·UIKit API에 넘길 레이아웃 수치를 담을 때. `spacing`, `padding`, `cornerRadius`, `frame` 값 등.
- 함수 시그니처가 프레임워크와 맞물릴 때. 예제의 `func gridItems(width: CGFloat) -> [GridItem]`이 그렇다.
- `GeometryProxy`에서 읽은 값을 그대로 다룰 때.

**`CGFloat`을 쓰지 말아야 할 때**

- **도메인 모델의 숫자.** 가격, 점수, 비율, 확률처럼 화면 좌표가 아닌 값은 `Double`을 쓴다.
- **저장·직렬화되는 값.** `Codable`로 저장하는 값이 아키텍처에 따라 정밀도가 달라지면 곤란하다. `Double`로 고정한다.
- **정수여야 하는 값.** 개수, 인덱스, 열 수는 `Int`다. 예제가 `columns`를 `Int`로 둔 것이 맞다.
- **크기를 정확히 지정해야 하는 값.** GPU 버퍼나 바이너리 포맷은 `Float32` 같은 명시적 타입을 쓴다.

한 문장으로 줄이면 이렇다. **화면 기하 값은 `CGFloat`, 그 밖의 실수는 `Double`.** SE-0307 덕분에 경계에서 변환 코드를 쓸 필요는 거의 없다.

### 부동소수점 비교 주의

`CGFloat`도 부동소수점이라 같은 함정을 공유한다.

> Unlike integer calculations, which always produce an exact result, floating-point math rounds results to the nearest representable number.

```swift
let width = totalWidth / 3
if width == 100 { }              // ⚠️ 위험
if abs(width - 100) < 0.001 { }  // 허용 오차로 비교
```

레이아웃 계산은 나눗셈이 흔하므로, 계산된 `CGFloat`을 `==`로 비교하는 코드는 피한다. 픽셀 경계에 맞춰야 한다면 `CGRect.integral`이나 `rounded()`를 쓴다.

## 학습 체크리스트

- [ ] `print(CGFloat.self, CGFloat.NativeType.self)`로 현재 빌드의 실제 타입을 확인한다.
- [ ] `MemoryLayout<CGFloat>.size`, `<Float>.size`, `<Double>.size`를 출력해 비교한다.
- [ ] `spacing * columns`를 그대로 써서 나오는 컴파일 에러 메시지를 직접 본다.
- [ ] `let spacing: CGFloat = 10`은 되는데 `Int` 변수는 안 되는 이유를 리터럴 관점에서 설명한다.
- [ ] `let ratio: Double = 0.6`을 만들어 `geometry.size.height * ratio`가 컴파일되는지 확인한다.
- [ ] `[Double]`을 `[CGFloat]` 자리에 넘겨 컬렉션은 자동 변환되지 않음을 확인한다.
- [ ] `CGRect`의 `midX`, `maxY`, `intersection`, `union`, `insetBy`를 직접 호출해 본다.
- [ ] `frame(in: .global)` 결과가 `CGRect`, `geometry.size`가 `CGSize`임을 타입으로 확인한다.
- [ ] `CGPoint`를 `var`로 만들어 `x`를 바꾸고, `let`으로는 안 되는 것을 확인한다 (값 타입 확인).
- [ ] `CGSize`를 복사해 한쪽을 바꿔도 원본이 그대로인지 확인한다.
- [ ] 도메인 값을 `CGFloat`으로 선언했을 때 어떤 문제가 생길 수 있는지 예를 들어 설명한다.
- [ ] `columns`를 `CGFloat`으로 바꿔 변환을 없앤 코드와 현재 코드의 가독성을 비교한다.

## 공식 참고 자료

- [Apple: Core Graphics](https://developer.apple.com/documentation/coregraphics)
- [Apple: CGFloat](https://developer.apple.com/documentation/corefoundation/cgfloat-swift.struct)
- [Apple: CGFloat.NativeType](https://developer.apple.com/documentation/corefoundation/cgfloat-swift.struct/nativetype)
- [Apple: CGPoint](https://developer.apple.com/documentation/corefoundation/cgpoint)
- [Apple: CGSize](https://developer.apple.com/documentation/corefoundation/cgsize)
- [Apple: CGRect](https://developer.apple.com/documentation/corefoundation/cgrect)
- [Apple: CGAffineTransform](https://developer.apple.com/documentation/corefoundation/cgaffinetransform)
- [Apple: CGContext](https://developer.apple.com/documentation/coregraphics/cgcontext)
- [Apple: CGPath](https://developer.apple.com/documentation/coregraphics/cgpath)
- [Swift Evolution SE-0307: Allow interchangeable use of CGFloat and Double types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0307-allow-interchangeable-use-of-double-cgfloat-types.md)
- [Swift 공식 문서: The Basics — Floating-Point Numbers](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/#Floating-Point-Numbers)
- [Swift 공식 문서: The Basics — Type Safety and Type Inference](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/#Type-Safety-and-Type-Inference)
