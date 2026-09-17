# `Canvas` 좌표계와 0~1 정규화 좌표

## 질문이 나온 코드

`chapter-43/chapter-43/ContentView.swift`는 눈송이 위치를 `Double`로 저장한 뒤 `Canvas`의 크기와 곱해 그린다.

```swift
Snowflake(
    x: .random(in: 0...1),
    y: .random(in: -0.2...0),
    // ...
)

Canvas { context, size in
    context.draw(
        Text("❄️"),
        at: CGPoint(
            x: snowflake.x * size.width,
            y: snowflake.y * size.height
        )
    )
}
```

화면 아래를 지난 눈송이는 다음 조건으로 다시 위로 보낸다.

```swift
if snowflakes[i].y > 1.2 {
    snowflakes[i].y = -0.2
}
```

## 공부할 내용

### `Snowflake.x`, `y`는 iOS가 정한 좌표 타입이 아니다

`Snowflake`의 `x`, `y`는 평범한 `Double`이므로 값의 범위에 제한이 없다. `0...1`을 쓰는 것은 이 예제를 작성한 사람이 **Canvas 크기에 대한 비율**로 위치를 저장하기로 정한 규칙이다. 이를 정규화 좌표라고 부를 수 있다.

- `x = 0`: 너비의 0%, 왼쪽 경계
- `x = 0.5`: 너비의 50%, 가로 중앙
- `x = 1`: 너비의 100%, 오른쪽 경계
- `y = 0`: 높이의 0%, 위쪽 경계
- `y = 0.5`: 높이의 50%, 세로 중앙
- `y = 1`: 높이의 100%, 아래쪽 경계

정규화 값은 실제 좌표가 되기 전에 `Canvas`가 넘겨준 `size`와 곱해진다.

```swift
let pointX = snowflake.x * size.width
let pointY = snowflake.y * size.height
```

예를 들어 Canvas가 390 × 844 point라면 `(x: 0.25, y: 0.5)`는 다음 위치가 된다.

```text
x = 0.25 × 390 = 97.5 point
y = 0.5  × 844 = 422 point
```

화면 크기가 달라져도 같은 비율의 위치를 유지하는 것이 이 표현의 장점이다.

### `Canvas`가 받는 `size`와 `CGPoint`가 실제 좌표다

Apple 문서에 따르면 `Canvas`의 renderer 클로저에는 `GraphicsContext`와 그리기에 사용할 `CGSize`가 전달된다. 코드의 `size.width`와 `size.height`가 현재 Canvas의 실제 너비와 높이다.

`context.draw(_:at:anchor:)`의 `at`은 context 안의 `CGPoint`를 받는다. 기본 `anchor`가 `.center`이므로 계산한 점에는 눈송이의 **중심**이 맞춰진다. `(0, 0)`에 그리면 눈송이 중심이 왼쪽 위 모서리에 놓여 절반 정도가 Canvas 바깥으로 나갈 수 있다.

```swift
context.draw(
    Text("❄️"),
    at: CGPoint(x: 0, y: 0),
    anchor: .topLeading
)
```

위처럼 `anchor`를 `.topLeading`으로 지정하면 눈송이의 왼쪽 위 모서리가 해당 좌표에 맞춰진다. 즉 좌표와 그려지는 콘텐츠의 기준점은 별개다.

### iOS 화면 좌표의 방향

iOS에서 화면에 놓인 2D 뷰를 다룰 때는 일반적으로 왼쪽 위가 원점이고, x는 오른쪽으로, y는 아래쪽으로 증가한다고 이해하면 된다.

```text
(0, 0) ───────────────→ +x
  │
  │       Canvas
  │
  ↓ +y
```

SwiftUI의 `UnitPoint` 문서도 왼쪽에서 오른쪽으로 쓰는 환경에서 원점이 왼쪽 위이고 양의 x가 오른쪽, 양의 y가 아래쪽이라고 설명한다. `UnitPoint`의 `0...1`은 뷰 내부의 상대 위치를 표현하므로 이 예제의 정규화 방식과 개념적으로 비슷하지만, 현재 `Snowflake.x`, `y` 자체가 `UnitPoint`인 것은 아니다.

### `y = 1.2`는 어디인가

코드가 실제 y 좌표를 다음처럼 계산하므로,

```swift
pointY = 1.2 * size.height
```

`y = 1.2`는 **Canvas 높이의 120%**, 즉 아래쪽 경계보다 Canvas 높이의 20%만큼 더 내려간 위치다.

Canvas 높이가 844 point라면 다음과 같다.

```text
아래쪽 경계: 1.0 × 844 = 844 point
y = 1.2:    1.2 × 844 = 1,012.8 point
경계 아래:              168.8 point
```

마찬가지로 초기값 `y = -0.2...0`은 위쪽 경계부터 Canvas 높이의 20%만큼 위에 있는 구간이다. 눈송이를 위쪽 바깥에서 생성하고, 아래쪽 바깥까지 충분히 이동한 뒤 다시 위로 보내기 위한 여유 구간이다.

```text
-0.2          0                    1          1.2
  위 여유 구간 |------ Canvas ------| 아래 여유 구간
```

값이 `0...1`을 벗어나도 `Double`이나 `CGPoint` 관점에서는 오류가 아니다. 단지 Canvas의 보이는 경계 밖에 그려질 뿐이다.

### point와 pixel은 다르다

`CGSize`와 `CGPoint`의 수치는 화면 pixel이 아니라 논리적인 point 단위다. 기기 화면 배율에 따라 1 point가 여러 물리 pixel로 렌더링될 수 있다. 따라서 눈송이 위치 계산은 기기 pixel 해상도가 아니라 SwiftUI layout 크기를 기준으로 해야 한다.

### local, global, named 좌표 공간

SwiftUI에는 무엇을 기준으로 좌표를 해석하는지 나타내는 좌표 공간이 있다.

- `.local`: 현재 뷰 자신의 좌표 공간
- `.global`: 뷰 계층 루트의 좌표 공간
- `.named(...)`: 개발자가 이름을 붙인 특정 조상 뷰의 좌표 공간

이 예제의 Canvas renderer는 Canvas 내부에서 그리므로 전달받은 `size`를 기준으로 local 좌표를 계산하면 충분하다. 화면 전체에서 뷰가 어디에 있는지 측정하거나 스크롤 컨테이너를 기준으로 위치를 비교할 때는 `GeometryProxy.frame(in:)`과 local/global/named 공간의 구분이 중요해진다.

### 정규화 변환을 함수로 분리하기

정규화 값이라는 의도를 코드에 드러내면 실수를 줄일 수 있다.

```swift
func point(normalizedX x: Double, y: Double, in size: CGSize) -> CGPoint {
    CGPoint(
        x: x * size.width,
        y: y * size.height
    )
}
```

```swift
context.draw(
    Text("❄️"),
    at: point(
        normalizedX: snowflake.x,
        y: snowflake.y,
        in: size
    )
)
```

필요하다면 저장 프로퍼티 이름도 `normalizedX`, `normalizedY`로 바꿔 단위가 point가 아님을 더 분명히 할 수 있다.

## 학습 체크리스트

- [ ] Canvas에 `(0, 0)`, `(0.5, 0.5)`, `(1, 1)` 점을 서로 다른 색으로 그려 위치를 확인한다.
- [ ] `anchor`를 `.center`와 `.topLeading`으로 바꿔 `(0, 0)`에서 보이는 차이를 확인한다.
- [ ] Canvas의 `size`를 출력하고 `y = 1.2`의 실제 point 좌표를 직접 계산한다.
- [ ] `y = -0.2`, `0`, `1`, `1.2`에 가로선을 그려 보이는 구간과 바깥 구간을 확인한다.
- [ ] Canvas frame을 서로 다른 크기로 바꿔도 정규화 좌표의 상대 위치가 유지되는지 확인한다.
- [ ] `Snowflake.x`, `y`의 이름을 `normalizedX`, `normalizedY`로 바꿨을 때 의도가 더 명확한지 비교한다.
- [ ] `GeometryReader`에서 `.local`, `.global`, `.named` frame을 출력해 기준점의 차이를 확인한다.
- [ ] point와 pixel의 차이를 설명하고 3x 화면에서 100 point가 몇 pixel인지 계산한다.

## 공식 참고 자료

- [Apple: Canvas](https://developer.apple.com/documentation/swiftui/canvas)
- [Apple: GraphicsContext.draw(_:at:anchor:)](https://developer.apple.com/documentation/swiftui/graphicscontext/draw(_:at:anchor:))
- [Apple: UnitPoint](https://developer.apple.com/documentation/swiftui/unitpoint)
- [Apple: UnitPoint.init() — 좌표축 방향](https://developer.apple.com/documentation/swiftui/unitpoint/init())
- [Apple: CoordinateSpace](https://developer.apple.com/documentation/swiftui/coordinatespace)
- [Apple: CoordinateSpaceProtocol](https://developer.apple.com/documentation/swiftui/coordinatespaceprotocol)
- [Apple: GeometryReader](https://developer.apple.com/documentation/swiftui/geometryreader)
- [Apple: GeometryProxy](https://developer.apple.com/documentation/swiftui/geometryproxy)
