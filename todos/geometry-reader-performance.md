# `GeometryReader`와 성능 — 중첩이 왜 문제가 되는가

용도와 활용 케이스는 [`GeometryReader`를 언제, 왜 쓰는가](./geometry-reader-use-cases.md)에 정리했다. 이 문서는 **성능 측면**만 파고든다.

## 질문이 나온 코드

`chapter-47/chapter-47/ContentView.swift`

```swift
struct MeasuringSizeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: SizePreferenceKey.self, value: proxy.size)
            }
        )
    }
}
```

이 modifier를 여러 뷰에 붙이거나, `GeometryReader` 안에서 또 `GeometryReader`를 쓰면 어떻게 되는가?

## 공부할 내용

### 결론 먼저

- "`GeometryReader`는 느리다"는 말은 **절반만 맞다.** 읽는 행위 자체보다 **그것이 유발하는 재평가와 레이아웃 재계산**이 비용이다.
- 진짜 문제는 중첩 자체보다 **측정 → 상태 변경 → 레이아웃 → 재측정** 순환이다.
- 중첩이 위험한 이유는 **레이아웃 협상 단계가 곱해지고**, 안쪽이 부모의 크기 확정에 의존해 계산이 직렬화되기 때문이다.
- 이 예제처럼 **`background` 안에서 `Color.clear`와 함께** 쓰는 패턴은 가장 안전한 축에 속한다.

### 비용의 정체 ① — 클로저 재평가

`GeometryReader`의 content는 클로저다. 크기가 바뀔 때마다 이 클로저가 다시 평가되고, 그 안의 뷰 트리가 다시 만들어진다.

Apple이 `onGeometryChange(for:of:action:)` 문서에서 하는 경고가 정확히 이 지점이다.

> The geometry of a view can change frequently, especially if the view is contained within a scroll view and that scroll view is scrolling.
>
> You should avoid updating large parts of your app whenever the scroll geometry changes.

핵심은 **"large parts"** 다. `GeometryReader`가 감싼 범위가 넓을수록 재평가 대상이 커진다. 그래서 같은 `GeometryReader`라도 이렇게 갈린다.

```swift
// 비싼 쪽 — 화면 전체가 재평가 대상
GeometryReader { proxy in
    VStack {
        ComplexHeader()
        ExpensiveList()
        Footer().frame(width: proxy.size.width * 0.8)
    }
}

// 싼 쪽 — 크기가 필요한 뷰만 감싼다
VStack {
    ComplexHeader()
    ExpensiveList()
    GeometryReader { proxy in
        Footer().frame(width: proxy.size.width * 0.8)
    }
    .frame(height: 60)
}
```

**`GeometryReader`를 트리의 위쪽에 두지 않는다**는 원칙이 여기서 나온다.

### 비용의 정체 ② — 레이아웃 협상 단계가 늘어난다

SwiftUI의 레이아웃은 부모가 크기를 제안하고 자식이 답하는 협상이다. `GeometryReader`는 이 흐름에 **한 단계를 더 끼워 넣는다.**

- 부모가 `GeometryReader`에 크기를 제안한다.
- `GeometryReader`는 제안받은 공간을 **전부 차지한다** (flexible preferred size).
- 그 확정된 크기를 클로저에 넘긴다.
- 클로저 안의 뷰들이 다시 레이아웃된다.

중첩하면 이 과정이 안쪽마다 반복된다.

```swift
GeometryReader { outer in          // ① 바깥 크기 확정 대기
    GeometryReader { inner in      // ② 바깥이 끝나야 시작
        GeometryReader { third in  // ③ 또 대기
            // ...
        }
    }
}
```

각 단계가 **앞 단계의 크기 확정에 의존**하므로 병렬화되지 않고 순차적으로 처리된다. 게다가 안쪽 값이 바뀌면 바깥으로 파급되는 경로까지 생긴다.

여기에 `GeometryReader`의 "공간을 다 차지한다"는 성질이 겹치면 레이아웃 자체가 의도와 어긋나기 시작한다. 성능 문제 이전에 **레이아웃 버그**가 먼저 오는 경우가 많다.

### 비용의 정체 ③ — 측정과 상태의 순환 (가장 위험)

실무에서 실제로 앱을 멈추게 만드는 것은 대개 이 패턴이다.

```text
GeometryReader가 크기 측정
        ↓
@State에 저장
        ↓
State 변경 → body 재평가
        ↓
레이아웃 다시 계산
        ↓
크기가 또 측정됨 → 처음으로
```

이 예제도 구조상 이 경로 위에 있다.

```swift
Text("This view knows its own size.")
    .frame(width: viewSize.width, height: viewSize.height)   // viewSize로 크기 결정
    .measureSzie { size in
        viewSize = size                                       // 측정값을 viewSize에
    }
```

지금은 두 가지가 순환을 막아 준다.

- `.frame`이 크기를 고정하므로 측정값 == 지정값이 되어 값이 수렴한다.
- `onPreferenceChange`가 `K.Value : Equatable`을 요구하고 **값이 바뀔 때만** 콜백한다.

두 번째가 특히 중요한 안전장치다. 자세한 내용은 [PreferenceKey 문서](./preference-key-and-onpreferencechange.md)에 있다.

하지만 `.frame`을 빼서 내용에 따라 크기가 결정되게 두면 값이 수렴하지 않고 계속 진동할 수 있다. **측정 대상과 크기 반영 대상을 분리하는 것**이 원칙이다.

### 그래서 이 예제의 패턴은 왜 안전한가

크기 측정 관용구가 항상 이 형태인 데에는 이유가 있다.

```swift
content.background(
    GeometryReader { proxy in
        Color.clear
            .preference(key: SizePreferenceKey.self, value: proxy.size)
    }
)
```

- **`background` 안에 있다.** `background`는 원본 뷰의 크기를 그대로 제안받으므로, `GeometryReader`가 공간을 다 차지해도 **레이아웃에 영향이 없다.**
- **`Color.clear`다.** 그리는 비용이 사실상 없고 자식 트리도 없다. 재평가되어도 다시 만들 것이 거의 없다.
- **`preference`만 올린다.** 상태 변경이 아니라 값 전달이라, 재평가가 그 자리에서 끝난다.

즉 앞서 말한 세 가지 비용을 모두 최소화한 배치다. `GeometryReader`를 써야 한다면 이 형태를 기본으로 삼는다.

### 중첩을 피하는 방법

**1. 한 번만 읽고 값을 아래로 전달한다**

```swift
// 나쁨
GeometryReader { outer in
    HStack {
        GeometryReader { inner in Cell(width: inner.size.width) }
        GeometryReader { inner in Cell(width: inner.size.width) }
    }
}

// 좋음 — 한 번 읽고 계산해서 넘긴다
GeometryReader { proxy in
    let cellWidth = proxy.size.width / 2
    HStack {
        Cell(width: cellWidth)
        Cell(width: cellWidth)
    }
}
```

chapter-45의 grid 예제가 이 방식이었다. `tabWidth`를 한 번 계산해 모든 셀에 나눠 준다.

**2. 좌표 공간에 이름을 붙여 바깥 `GeometryReader`를 없앤다**

바깥을 두는 이유가 "기준 컨테이너가 필요해서"라면, `coordinateSpace(_:)`로 대체할 수 있다.

```swift
ScrollView {
    ForEach(items) { item in
        RowView(item)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: FramePreferenceKey.self,
                        value: proxy.frame(in: .named("scroll"))
                    )
                }
            )
    }
}
.coordinateSpace(.named("scroll"))
```

바깥 `GeometryReader` 없이도 조상 기준 좌표를 얻는다. [좌표 공간 문서](./coordinate-space-local-global-named.md)에 정리했다.

**3. 목적에 맞는 전용 API로 바꾼다**

| 목적 | 대안 | 이점 |
| --- | --- | --- |
| 컨테이너 대비 비율 크기 | `containerRelativeFrame(_:alignment:)` | 레이아웃 단계 추가 없음 |
| 기하 값 변화 감지 | `onGeometryChange(for:of:action:)` | `Equatable` 비교로 호출 최소화 |
| 위치 기반 시각 효과 | `visualEffect(_:)` | **레이아웃을 바꾸지 않는다** |
| 커스텀 배치 로직 | `Layout` 프로토콜 | 협상에 직접 참여 |

`onGeometryChange`는 이 문제를 정면으로 겨냥해 만들어진 API다.

> To aid in this, you provide two closures to this modifier:
> - transform: This converts a value of `GeometryProxy` to your own data type.
> - action: This provides the data type you created in of and is called whenever the data type changes.

`transform`으로 필요한 값만 뽑고, 그 값이 **실제로 바뀔 때만** `action`이 불린다. `GeometryProxy` 전체가 아니라 `Bool` 하나만 보게 만들 수 있다는 뜻이다.

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

`visualEffect`는 `GeometryProxy`를 받으면서도 레이아웃에 개입하지 않는다.

```swift
ContentView()
    .visualEffect { content, geometryProxy in
        content.offset(geometryProxy.size)
    }
```

**4. `Layout` 프로토콜로 직접 배치한다**

크기 계산이 복잡하다면 `GeometryReader`로 우회하지 말고 협상에 직접 참여하는 것이 정석이다.

> - `sizeThatFits(proposal:subviews:cache:)` reports the size of the composite layout view.
> - `placeSubviews(in:proposal:subviews:cache:)` assigns positions to the container's subviews.

`cache` 파라미터가 있다는 점이 성능 관점에서 의미가 있다. 계산 결과를 재사용할 수 있다.

**5. 애니메이션이 얽히면 `geometryGroup()`**

기하 값 변화가 애니메이션과 만나면 자식마다 따로 적용되어 어긋날 수 있다.

> By default SwiftUI views push position and size changes down through the view hierarchy, so that only views that draw something (known as leaf views) apply the current animation to their frame rectangle. However in some cases this coalescing behavior can give undesirable results; inserting a geometry group can correct that. A group acts as a barrier between the parent view and its subviews, forcing the position and size values to be resolved and animated by the parent, before being passed down to each subview.

```swift
VStack {
    ForEach(items) { item in
        ItemView(item: item)
            .geometryGroup()
    }
}
```

### 실무 체크리스트

```text
GeometryReader를 쓰기 전에

□ 전용 API로 대체 가능한가? (containerRelativeFrame / onGeometryChange / visualEffect)
□ 감싸는 범위가 필요 최소한인가?
□ background나 overlay 안에 둘 수 있는가?
□ 측정한 값으로 자기 자신의 크기를 정하고 있지 않은가?
□ 중첩되어 있다면 한 번만 읽고 값을 전달할 수 있는가?
□ 스크롤뷰 안이라면 재평가 범위가 작은가?
□ 상태 저장이 필요하다면 Equatable 비교로 걸러지는가?
```

### 균형 잡기

과도한 회피도 답은 아니다. 정적인 화면에서 `GeometryReader` 하나를 쓰는 것은 아무 문제가 없다. 문제가 되는 조건은 대체로 다음이 겹칠 때다.

- 스크롤·드래그·애니메이션으로 **크기가 계속 변하고**
- 감싼 범위가 **넓고**
- 측정값이 **상태로 흘러들어** 재렌더링을 유발할 때

이 예제처럼 드래그로 크기를 바꾸는 코드는 세 번째 조건에 해당하지만, `Equatable` 비교와 `Color.clear` 덕분에 실질 비용이 억제된다. 측정을 진짜 최적화하려면 다음 단계는 `onGeometryChange`로 옮기는 것이다.

## 학습 체크리스트

- [ ] `GeometryReader` 클로저 안에 `print`를 넣어 드래그 중 몇 번 평가되는지 센다.
- [ ] `MeasuringSizeModifier`를 여러 뷰에 붙이고 호출 횟수가 어떻게 늘어나는지 본다.
- [ ] `GeometryReader`를 3단 중첩해 클로저 평가 순서와 횟수를 관찰한다.
- [ ] 같은 레이아웃을 중첩 없이 값 전달 방식으로 다시 짜고 평가 횟수를 비교한다.
- [ ] `.frame(width:height:)`를 제거해 측정↔상태 순환이 수렴하지 않는지 확인한다.
- [ ] `onPreferenceChange`의 `action`에 `print`를 넣어 `Equatable` 필터링 효과를 확인한다.
- [ ] 같은 기능을 `onGeometryChange(for: CGSize.self)`로 옮기고 호출 횟수를 비교한다.
- [ ] `background` 안이 아니라 본문에 `GeometryReader`를 넣어 레이아웃이 깨지는 것을 본다.
- [ ] `ScrollView` 안 셀마다 `GeometryReader`를 넣고 스크롤 시 부하를 체감한다.
- [ ] 같은 화면을 `containerRelativeFrame`으로 바꿔 코드와 부하를 비교한다.
- [ ] `visualEffect`로 offset을 주는 것과 `GeometryReader` 방식의 레이아웃 차이를 확인한다.
- [ ] 애니메이션이 어긋나는 상황을 만들고 `geometryGroup()`으로 교정한다.
- [ ] Xcode Instruments의 SwiftUI 템플릿으로 body 재평가 횟수를 측정한다.

## 공식 참고 자료

- [Apple: GeometryReader](https://developer.apple.com/documentation/swiftui/geometryreader)
- [Apple: GeometryProxy](https://developer.apple.com/documentation/swiftui/geometryproxy)
- [Apple: view.onGeometryChange(for:of:action:)](https://developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:))
- [Apple: view.containerRelativeFrame(_:alignment:)](https://developer.apple.com/documentation/swiftui/view/containerrelativeframe(_:alignment:))
- [Apple: view.visualEffect(_:)](https://developer.apple.com/documentation/swiftui/view/visualeffect(_:))
- [Apple: view.geometryGroup()](https://developer.apple.com/documentation/swiftui/view/geometrygroup())
- [Apple: view.coordinateSpace(_:)](https://developer.apple.com/documentation/swiftui/view/coordinatespace(_:))
- [Apple: Layout](https://developer.apple.com/documentation/swiftui/layout)
- [Apple: Layout adjustments](https://developer.apple.com/documentation/swiftui/layout-adjustments)
- [Apple: Inspecting view layout](https://developer.apple.com/documentation/swiftui/inspecting-view-layout)
