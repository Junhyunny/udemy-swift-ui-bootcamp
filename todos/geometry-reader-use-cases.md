# `GeometryReader`를 언제, 왜 쓰는가

## 질문이 나온 코드

`chapter-44/chapter-44/ContentView.swift`의 `GeometryReaderExample1`은 부모가 준 크기를 읽어 자식 크기를 비율로 계산한다.

```swift
GeometryReader { geometry in
    VStack {
        Text("Width: \(Int(geometry.size.width))")
        Text("Height: \(Int(geometry.size.height))")
        Rectangle()
            .frame(
                width: geometry.size.width * 0.8,
                height: geometry.size.height * 0.8
            )
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
.frame(height: 300)
.border(.gray)
```

## 공부할 내용

### `GeometryReader`는 "부모가 내게 준 공간"을 자식에게 알려주는 컨테이너다

SwiftUI의 기본 레이아웃 협상은 **부모가 자식에게 제안 크기를 주고, 자식이 스스로 크기를 정해 답하는** 단방향 흐름이다. 그래서 자식은 보통 부모의 실제 크기를 알 수 없다.

`GeometryReader`는 이 흐름에 창을 하나 낸다. 자기 자신이 부모로부터 받은 영역을 `GeometryProxy`로 감싸 content 클로저에 넘겨준다.

```swift
GeometryReader { geometry in
    // geometry.size == GeometryReader 자신이 차지한 크기
}
```

`GeometryProxy`에서 읽을 수 있는 값은 다음과 같다.

| 멤버 | 타입 | 의미 |
| --- | --- | --- |
| `size` | `CGSize` | 컨테이너에 할당된 너비·높이 |
| `safeAreaInsets` | `EdgeInsets` | 안전 영역 여백 |
| `frame(in:)` | `CGRect` | 지정한 좌표 공간 기준 위치와 크기 |
| `bounds(of:)` | `CGRect?` | named 좌표 공간 자체의 경계 |
| `transform(in:)` | `CGAffineTransform` | 좌표 공간까지의 변환 |
| `subscript(_:)` | `Anchor<T>` 의 값 | anchor를 실제 값으로 해석 |

`frame(in:)`과 좌표 공간은 [coordinate-space-local-global-named.md](./coordinate-space-local-global-named.md)에서 따로 정리한다.

### 핵심 성질: 주어진 공간을 전부 차지한다

Apple 문서는 `GeometryReader`를 이렇게 설명한다.

> This view returns a flexible preferred size to its parent layout.

즉 `GeometryReader`는 자식 크기에 맞춰 줄어들지 않고, **부모가 제안한 공간을 최대한 채운다**. 이것이 `GeometryReader`를 쓸 때 레이아웃이 갑자기 커지거나 요소가 왼쪽 위로 몰리는 이유다.

예제 코드가 두 개의 `frame`을 쓰는 이유도 여기에 있다.

- 바깥의 `.frame(height: 300)`: `GeometryReader`가 세로로 무한히 늘어나지 않게 높이를 300으로 고정한다. 그래서 `geometry.size.height`가 300이 된다.
- 안쪽의 `.frame(maxWidth: .infinity, maxHeight: .infinity)`: `VStack`을 `GeometryReader` 영역 전체로 늘려 가운데 정렬처럼 보이게 한다. 이 줄을 지우면 `VStack`은 자기 내용 크기만 차지하고 좌측 상단에 붙는다.

두 번째 성질도 같이 기억한다. content 클로저 안에서 위치를 지정하지 않은 뷰는 **좌측 상단(topLeading)** 을 기준으로 배치된다. 그래서 `GeometryReaderExample2`는 `.position(x:y:)`으로 좌표를 직접 지정해 중앙에 놓는다.

### 언제 쓰는가 — 실제 활용 케이스

**1. 부모 크기에 대한 비율 레이아웃**

디자인이 "화면 너비의 80%", "높이의 1/3"처럼 비율로 주어질 때 쓴다. 예제의 `geometry.size.width * 0.8`이 그 형태다.

```swift
GeometryReader { geometry in
    HStack(spacing: 0) {
        Sidebar().frame(width: geometry.size.width * 0.3)
        Detail().frame(width: geometry.size.width * 0.7)
    }
}
```

**2. 스크롤 위치에 따른 효과 (parallax, 축소, fade)**

셀이 화면 어디쯤 있는지를 읽어 변형에 반영한다. 캐러셀의 중앙 카드 확대, 헤더의 stretchy 이미지가 대표적이다.

```swift
ScrollView {
    ForEach(items) { item in
        GeometryReader { geometry in
            let y = geometry.frame(in: .scrollView).minY
            Card(item)
                .scaleEffect(1 - abs(y) / 2000)
        }
        .frame(height: 200)
    }
}
```

**3. 뷰의 실제 크기를 측정해 다른 뷰에 반영**

렌더링된 텍스트 높이에 맞춰 배경이나 형제 뷰 크기를 맞출 때 쓴다. 보통 `overlay`나 `background`에 넣어 **레이아웃에 영향을 주지 않는 자리**에서 측정한다.

```swift
Text(longText)
    .background(
        GeometryReader { geometry in
            Color.clear
                .onAppear { measuredHeight = geometry.size.height }
        }
    )
```

`background`/`overlay`는 부모 뷰 크기를 그대로 제안받으므로, "공간을 전부 차지한다"는 성질이 부작용이 되지 않는다. 이것이 `GeometryReader`를 안전하게 쓰는 가장 흔한 관용구다.

**4. 좌표를 직접 계산해 그리는 커스텀 드로잉**

`Path`, `Shape`, `Canvas`와 함께 컨테이너 크기 기준의 좌표를 만든다. 다만 `Shape`는 `path(in rect:)`로 이미 `rect`를 받으므로 `GeometryReader`가 필요 없는 경우가 많다.

**5. 안전 영역 크기를 알아야 할 때**

`geometry.safeAreaInsets`로 노치·홈 인디케이터 여백을 수치로 얻는다.

### 장점

- 부모의 실제 크기와 위치를 자식이 알 수 있는, SwiftUI가 제공하는 표준 수단이다.
- 기기·방향·분할 화면이 달라져도 비율 기반 레이아웃이 그대로 유지된다.
- `frame(in:)`으로 화면 전체나 특정 조상 기준의 절대 위치를 얻을 수 있어 스크롤 연동 효과를 만들 수 있다.

### 단점과 대안

`GeometryReader`는 값이 싸지 않다. Apple도 `onGeometryChange(for:of:action:)` 문서에서 이렇게 경고한다.

> The geometry of a view can change frequently, especially if the view is contained within a scroll view and that scroll view is scrolling. You should avoid updating large parts of your app whenever the scroll geometry changes.

정리하면 다음 문제가 있다.

- 부모 공간을 다 차지해 주변 레이아웃을 망가뜨린다.
- 내용 크기에 맞춰 줄어들지 않으므로 `List`나 `VStack` 안에 그냥 넣으면 높이가 폭발한다.
- 크기 변화마다 content 클로저가 다시 평가되어 스크롤 중 성능 부담이 된다.
- 측정값을 `@State`에 저장하면 "측정 → 상태 변경 → 레이아웃 → 재측정" 순환에 빠질 수 있다.

그래서 목적별로 더 좁은 API를 먼저 검토한다.

| 목적 | 먼저 볼 API |
| --- | --- |
| 컨테이너(화면·스크롤뷰·탭) 크기 비율로 크기 지정 | `containerRelativeFrame(_:alignment:)` |
| 기하 값 변화에만 반응 | `onGeometryChange(for:of:action:)` |
| 위치 기반 시각 효과만 필요 | `visualEffect(_:)` |
| 조상 좌표 공간 기준 위치 필요 | `coordinateSpace(_:)` + `frame(in: .named(...))` |
| 깊이(z)까지 읽어야 할 때 | `GeometryReader3D` |

`containerRelativeFrame`은 컨테이너 크기에서 안전 영역을 뺀 값을 기준으로 크기를 정해 준다.

```swift
ScrollView(.horizontal) {
    LazyHStack(spacing: 0) {
        ForEach(items) { item in
            Rectangle()
                .fill(.purple)
                .containerRelativeFrame([.horizontal, .vertical])
        }
    }
}
```

`visualEffect`는 `GeometryProxy`를 받지만 레이아웃을 바꾸지 않고 그리기만 바꾼다.

```swift
ContentView()
    .visualEffect { content, geometryProxy in
        content.offset(geometryProxy.size)
    }
```

`GeometryReader3D`에 대해서는 Apple 문서가 이렇게 못 박는다.

> Use the 3D version only in situations where you need to read depth, because it affects depth layout when used in a container like a ZStack.

### 판단 기준 요약

```text
크기·위치 정보가 필요한가?
├─ 아니오 → stack, grid, frame, padding으로 충분
└─ 예
   ├─ 컨테이너 대비 비율 크기만 필요 → containerRelativeFrame
   ├─ 값 변화에 반응만 필요 → onGeometryChange
   ├─ 시각 효과만 필요 → visualEffect
   └─ 크기·좌표를 직접 계산해야 함 → GeometryReader
      └─ 주변 레이아웃을 건드리면 안 되면 background/overlay 안에서 사용
```

## 학습 체크리스트

- [ ] `GeometryReaderExample1`에서 `.frame(height: 300)`을 지우고 `geometry.size.height`가 어떻게 바뀌는지 확인한다.
- [ ] 안쪽 `.frame(maxWidth: .infinity, maxHeight: .infinity)`를 지우고 `VStack`이 좌측 상단으로 붙는 것을 확인한다.
- [ ] `GeometryReader`를 `VStack` 안에 그냥 넣어 형제 뷰가 밀려나는 현상을 재현한다.
- [ ] 같은 레이아웃을 `containerRelativeFrame`으로 다시 구현하고 코드 양을 비교한다.
- [ ] `Text`의 높이를 `background(GeometryReader { ... })`로 측정해 `@State`에 담아 본다.
- [ ] 같은 측정을 `onGeometryChange(for: CGSize.self)`로 바꿔 클로저 호출 횟수를 `print`로 비교한다.
- [ ] `ScrollView` 안에서 셀의 `frame(in: .scrollView).minY`를 출력해 스크롤에 따라 값이 흐르는 것을 본다.
- [ ] `geometry.safeAreaInsets`를 출력해 기기별 여백 값을 확인한다.
- [ ] `visualEffect`로 offset을 주는 것과 `GeometryReader` 안에서 offset을 주는 것의 레이아웃 차이를 비교한다.

## 공식 참고 자료

- [Apple: GeometryReader](https://developer.apple.com/documentation/swiftui/geometryreader)
- [Apple: GeometryProxy](https://developer.apple.com/documentation/swiftui/geometryproxy)
- [Apple: GeometryProxy.size](https://developer.apple.com/documentation/swiftui/geometryproxy/size)
- [Apple: GeometryProxy.safeAreaInsets](https://developer.apple.com/documentation/swiftui/geometryproxy/safeareainsets)
- [Apple: GeometryReader3D](https://developer.apple.com/documentation/swiftui/geometryreader3d)
- [Apple: view.onGeometryChange(for:of:action:)](https://developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:))
- [Apple: view.containerRelativeFrame(_:alignment:)](https://developer.apple.com/documentation/swiftui/view/containerrelativeframe(_:alignment:))
- [Apple: view.visualEffect(_:)](https://developer.apple.com/documentation/swiftui/view/visualeffect(_:))
- [Apple: Layout adjustments](https://developer.apple.com/documentation/swiftui/layout-adjustments)
