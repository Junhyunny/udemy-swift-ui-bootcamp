# 좌표 공간 — local, global, named와 부모·자식 뷰의 관계

## 질문이 나온 코드

`chapter-44/chapter-44/ContentView.swift`의 `GeometryReaderExample2`는 같은 뷰의 frame을 두 개의 좌표 공간으로 출력한다.

```swift
ZStack {
    Color.gray.opacity(0.2)
    GeometryReader { geometry in
        Rectangle()
            .foregroundStyle(/* ... */)
        VStack(alignment: .leading) {
            Text("Local: \(geometryString(geometry.frame(in: .local)))")
            Text("Global: \(geometryString(geometry.frame(in: .global)))")
        }
        .position(
            x: geometry.size.width / 2,
            y: geometry.size.height / 2
        )
    }
}
.frame(width: 300, height: 300)
```

```swift
func geometryString(_ frame: CGRect) -> String {
    return "x: \(Int(frame.origin.x)), y: \(Int(frame.origin.y)), width: \(Int(frame.size.width)), height: \(Int(frame.size.height))"
}
```

## 공부할 내용

### 질문 1. 상대적인 좌표와 사이즈를 측정하기 위한 것인가

그렇다. 다만 **사이즈는 좌표 공간과 무관하고, 좌표(origin)만 좌표 공간에 따라 달라진다.**

`geometry.size`는 컨테이너에 할당된 크기 하나뿐이다. `frame(in: .local)`과 `frame(in: .global)`의 `size`는 항상 같은 값이 나온다. 달라지는 것은 `origin`이다.

예제를 실행하면 대략 다음과 같이 나온다.

```text
Local:  x: 0,  y: 0,   width: 300, height: 300
Global: x: 46, y: 220, width: 300, height: 300
```

- `.local`의 origin은 **항상 `(0, 0)`** 이다. 자기 자신을 기준으로 자기 위치를 물었으니 원점일 수밖에 없다.
- `.global`의 origin은 이 300×300 영역이 **화면(뷰 계층 루트) 안에서 어디에 있는지**를 알려준다.

그래서 실무에서 필요한 정보는 보통 이렇게 나뉜다.

| 알고 싶은 것 | 쓰는 값 |
| --- | --- |
| 내 영역이 얼마나 큰가 | `geometry.size` |
| 내 영역 안에서의 상대 위치 | `frame(in: .local)` 또는 `size` 기반 계산 |
| 화면 전체에서 내가 어디 있는가 | `frame(in: .global)` |
| 특정 조상 뷰 기준으로 내가 어디 있는가 | `frame(in: .named("..."))` |
| 스크롤뷰 기준으로 내가 어디 있는가 | `frame(in: .scrollView)` |

### 질문 2. local 뷰, global 뷰라는 컨셉이 있는가

**없다.** local과 global은 뷰의 종류가 아니라 **좌표를 해석하는 기준**이다. "local 뷰"라는 것은 없고, "local 좌표 공간"이 있다.

Apple 문서의 정의가 정확하다.

> All geometric properties of a view, including size, position, and transform, are defined within the local coordinate space of the view's parent. These values can be converted into other coordinate spaces by passing types conforming to this protocol into functions such as `GeometryProxy.frame(in:)`.

즉 SwiftUI의 모든 기하 값은 **기본적으로 부모의 local 좌표 공간에서 정의**되고, `frame(in:)`은 그 값을 다른 기준으로 **변환**해 주는 함수다. 값 자체가 여러 개 있는 게 아니라, 하나의 위치를 어느 원점에서 재느냐의 차이다.

```text
화면(global) 원점
┌───────────────────────────────┐
│  (0, 0)                       │
│                               │
│      ZStack / GeometryReader  │
│      ┌───────────────┐        │
│      │ (0,0) ← local │        │
│      │               │        │
│      │   300 × 300   │        │
│      └───────────────┘        │
│      ↑                        │
│      이 지점이 global origin   │
└───────────────────────────────┘
```

### 질문 3. coordinate space 개념은 무엇인가

좌표 공간은 **"이 좌표의 `(0, 0)`은 어디인가"를 정하는 기준 프레임**이다. SwiftUI는 세 가지를 기본 제공한다.

```swift
static var local: LocalCoordinateSpace { get }
static var global: GlobalCoordinateSpace { get }
static func named(_ name: some Hashable) -> NamedCoordinateSpace
static var scrollView: NamedCoordinateSpace { get }
```

- `.local` — 값을 읽는 뷰 자신의 좌표 공간. origin은 자기 자신의 좌측 상단.
- `.global` — 뷰 계층 루트의 좌표 공간. 앱 화면(윈도우) 기준의 절대 좌표에 가깝다.
- `.named(_:)` — 개발자가 이름을 붙인 특정 조상 뷰의 좌표 공간.
- `.scrollView` — 시스템이 미리 이름을 붙여 둔, 가장 가까운 스크롤뷰의 좌표 공간.

`CoordinateSpace` 열거형 자체는 이제 직접 다루지 않는다.

> You don't typically use `CoordinateSpace` directly. Instead, use the static properties and functions of `CoordinateSpaceProtocol` such as `.global`, `.local`, and `.named(_:)`.

### named 좌표 공간 — 부모·자식 사이의 기준점 만들기

`.local`은 너무 좁고 `.global`은 너무 넓을 때가 많다. "이 카드가 **리스트 컨테이너** 안에서 어디에 있는가"처럼 중간 조상을 기준으로 재고 싶다면, 조상에 `coordinateSpace(_:)`로 이름을 붙이고 자손에서 `.named(_:)`로 참조한다.

```swift
VStack {
    GeometryReader { geometryProxy in
        let distanceFromTop = geometryProxy.frame(in: "container").origin.y
        Text("This view is \(distanceFromTop) points from the top of the VStack")
    }
    .padding()
}
.coordinateSpace(.named("container"))
```

핵심은 방향이다. **이름은 조상이 선언하고, 자손이 읽는다.** 자손이 부모를 직접 가리킬 방법은 없으므로 부모가 미리 이름을 심어 두는 구조다.

`.global`이 아니라 named를 쓰는 이유는 다음과 같다.

- 화면 위치가 아니라 컨테이너 안에서의 진행도(progress)를 알고 싶을 때 의미가 맞는다.
- 컨테이너가 화면 어디에 놓이든 값이 변하지 않아 재사용 가능한 컴포넌트를 만들 수 있다.
- 안전 영역·네비게이션 바 높이 같은 외부 요인에 값이 흔들리지 않는다.

제스처도 같은 좌표 공간 개념을 공유한다. Apple 문서의 예제는 `DragGesture(coordinateSpace: .named("stack"))`으로 드래그 위치를 조상 `VStack` 기준으로 받는다.

```swift
VStack {
    Color.red.frame(width: 100, height: 100)
        .overlay(circle)
    Text("Location: \(Int(location.x)), \(Int(location.y))")
}
.coordinateSpace(.named("stack"))
```

### `frame(in:)`과 `bounds(of:)`의 차이

```swift
func frame(in coordinateSpace: some CoordinateSpaceProtocol) -> CGRect
func bounds(of coordinateSpace: NamedCoordinateSpace) -> CGRect?
```

- `frame(in:)` — **내 영역**을 그 좌표 공간 기준으로 표현한 사각형.
- `bounds(of:)` — **그 좌표 공간 자체**의 사각형. named 공간에만 쓸 수 있고, 해당 공간을 찾지 못하면 `nil`이다.

둘을 조합하면 "내가 스크롤뷰 안에서 얼마나 보이는가"를 계산할 수 있다. Apple 문서의 자동재생 예제가 정확히 그 형태다.

```swift
.onGeometryChange(for: Bool.self) { proxy in
    let frame = proxy.frame(in: .scrollView)
    let bounds = proxy.bounds(of: .scrollView) ?? .zero
    let intersection = frame.intersection(
        CGRect(origin: .zero, size: bounds.size))
    let visibleHeight = intersection.size.height
    return (visibleHeight / frame.size.height) > 0.75
} action: { isVisible in
    video.updateAutoplayingState(isVisible: isVisible)
}
```

### 좌표축의 방향과 layout direction

Apple은 좌표축 방향을 이렇게 규정한다.

> In SwiftUI, the view's coordinate space uses x to represent a horizontal direction and y to represent a vertical direction. The value of x starts at 0 at the leading edge of a view, and increases as the location moves toward the trailing edge of a view. The value of y starts at 0 at the top edge of a view, and increases as the location moves toward the bottom edge of a view. Don't assume the leading edge is always on the left, because it changes with the layout direction. When the layout direction is set to right-to-left, the 0 horizontal value is on the right side of the view.

```text
(0, 0) ──── leading → trailing ────→ +x
  │
  │            뷰 영역
  │
  ↓ +y
```

`x = 0`이 항상 왼쪽이 아니라 **leading**이라는 점이 중요하다. RTL 언어 환경에서는 오른쪽이 원점이 된다. 이 예제의 `Canvas` 정규화 좌표와 같은 방향 규칙을 쓰므로 [canvas-coordinate-space-and-normalization.md](./canvas-coordinate-space-and-normalization.md)와 함께 보면 좋다.

### `.position`은 부모 좌표 공간에 직접 배치한다

예제는 텍스트를 중앙에 놓기 위해 `.position`을 쓴다.

```swift
.position(
    x: geometry.size.width / 2,
    y: geometry.size.height / 2
)
```

`offset`과 `position`의 차이를 Apple은 이렇게 구분한다.

> A position modifier overrides where the parent view places its content. The modifier renders the view at a location offset from the origin of the parent view, unlike an offset modifier that shifts the view from the location chosen by the parent view.

- `offset(x:y:)` — 부모가 정한 위치에서 **상대적으로 이동**한다.
- `position(x:y:)` — 부모 좌표 공간의 **절대 좌표에 배치**한다. 지정한 점에 뷰의 **중심**이 맞춰진다.

`GeometryReader`는 자식을 좌측 상단부터 배치하므로, 중앙에 두려면 `.position`으로 `size / 2`를 직접 지정하는 것이 이 예제의 방식이다. `size.width / 2`가 중앙이 되는 것도 `position`의 기준점이 중심이기 때문이다.

### 정리

```text
좌표 공간은 "원점을 어디로 잡을까"의 선택이다.

.local          → 나 자신의 좌측 상단 (origin은 늘 0,0)
.named("x")     → 이름 붙인 조상의 좌측 상단
.scrollView     → 가장 가까운 스크롤뷰
.global         → 뷰 계층 루트

size는 어느 공간에서 물어도 같다. origin만 달라진다.
```

## 학습 체크리스트

- [ ] `GeometryReaderExample2`를 실행해 Local origin이 `(0, 0)`, Global origin이 화면 위치인 것을 확인한다.
- [ ] `frame(in: .local).size`와 `frame(in: .global).size`, `geometry.size`가 모두 같은지 출력해 확인한다.
- [ ] `VStack` 바깥에 `.padding(50)`을 추가하고 Global origin만 바뀌는 것을 확인한다.
- [ ] `ZStack`에 `.coordinateSpace(.named("box"))`를 붙이고 `frame(in: .named("box"))` 결과를 local·global과 비교한다.
- [ ] `bounds(of: .named("box"))`와 `frame(in: .named("box"))`가 무엇을 가리키는지 값으로 구분한다.
- [ ] `ScrollView`에 예제를 넣고 `frame(in: .scrollView).minY`가 스크롤에 따라 변하는 것을 확인한다.
- [ ] `.position`을 `.offset`으로 바꿔 텍스트가 어디로 가는지 비교한다.
- [ ] `.position(x: 0, y: 0)`을 지정해 뷰의 중심이 좌측 상단에 맞춰지는 것을 확인한다.
- [ ] `environment(\.layoutDirection, .rightToLeft)`를 적용해 x 원점이 오른쪽으로 옮겨지는지 확인한다.
- [ ] `DragGesture(coordinateSpace: .named("box"))`로 드래그 좌표를 받아 local·global 좌표와 비교한다.

## 공식 참고 자료

- [Apple: CoordinateSpaceProtocol](https://developer.apple.com/documentation/swiftui/coordinatespaceprotocol)
- [Apple: CoordinateSpace](https://developer.apple.com/documentation/swiftui/coordinatespace)
- [Apple: CoordinateSpaceProtocol.local](https://developer.apple.com/documentation/swiftui/coordinatespaceprotocol/local)
- [Apple: CoordinateSpaceProtocol.global](https://developer.apple.com/documentation/swiftui/coordinatespaceprotocol/global)
- [Apple: CoordinateSpaceProtocol.named(_:)](https://developer.apple.com/documentation/swiftui/coordinatespaceprotocol/named(_:))
- [Apple: CoordinateSpaceProtocol.scrollView](https://developer.apple.com/documentation/swiftui/coordinatespaceprotocol/scrollview)
- [Apple: view.coordinateSpace(_:)](https://developer.apple.com/documentation/swiftui/view/coordinatespace(_:))
- [Apple: GeometryProxy.frame(in:)](https://developer.apple.com/documentation/swiftui/geometryproxy/frame(in:))
- [Apple: GeometryProxy.bounds(of:)](https://developer.apple.com/documentation/swiftui/geometryproxy/bounds(of:))
- [Apple: Making fine adjustments to a view's position](https://developer.apple.com/documentation/swiftui/making-fine-adjustments-to-a-view-s-position)
- [Apple: view.position(x:y:)](https://developer.apple.com/documentation/swiftui/view/position(x:y:))
