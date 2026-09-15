# `@Namespace` — 두 뷰의 기하 정보를 잇는 이름표

## 질문이 나온 코드

`chapter-156/chapter-156/ContentView.swift`

```swift
struct SegmentedControlSwiftUI: View {
    @State private var selectedTab: AppTab = .swiftUI
    @Namespace private var animation
    // ...
}
```

이 `animation`은 아래에서만 쓰인다.

```swift
.background {
    if selectedTab == tab {
        RoundedRectangle(cornerRadius: 5, style: .circular)
            .frame(height: 3)
            .offset(y: 15)
            .foregroundStyle(selectedTab.color.gradient)
            .matchedGeometryEffect(id: "selected_tab", in: animation)
    }
}
```

`@Namespace`가 무슨 용도인지가 질문이다.

## 공부할 내용

### 결론 먼저

`@Namespace`는 **`matchedGeometryEffect`가 짝을 찾을 범위(namespace)를 만들어 주는 property wrapper**다. 혼자서는 아무 일도 하지 않는다. `matchedGeometryEffect(id:in:)`의 `in:` 자리에 넘겨 주는 **이름표 전용 값**이다.

```text
@Namespace   →  "여기가 하나의 그룹이다"   (범위)
id: "..."    →  "그 그룹 안에서 이 짝이다"  (식별자)
```

둘을 합친 `(namespace, id)` 쌍이 같은 두 뷰를 SwiftUI가 **"사실은 같은 하나의 뷰"**로 간주하고, 위치와 크기를 이어서 애니메이션한다.

공식 문서의 정의는 이렇다.

> A dynamic property type that allows access to a namespace defined by the persistent identity of the object containing the property (e.g. a view).

### 왜 범위가 따로 필요한가

`id`만 있으면 될 것 같지만, `id`는 그냥 `"selected_tab"` 같은 문자열이다. 같은 앱 안의 **다른 화면에서도 같은 문자열을 쓸 수 있다.** 그러면 서로 상관없는 뷰끼리 짝이 맺힐 것이다.

`@Namespace`는 그 충돌을 막는다. **선언한 뷰 인스턴스마다 고유한 값**이 만들어지므로, 아래 두 컨트롤이 화면에 동시에 있어도 서로를 침범하지 않는다.

```text
SegmentedControlSwiftUI 인스턴스 A
  @Namespace animation  →  ID(A)
  matchedGeometryEffect(id: "selected_tab", in: ID(A))   ← A의 짝

SegmentedControlSwiftUI 인스턴스 B
  @Namespace animation  →  ID(B)
  matchedGeometryEffect(id: "selected_tab", in: ID(B))   ← B의 짝
```

같은 문자열 `"selected_tab"`을 써도 범위가 다르니 섞이지 않는다. 이 코드에서 `SegmentedControlSwiftUI`와 `ReusableSegmentedControl`이 **각자 `@Namespace`를 따로 선언한 것**도 같은 이유다.

### 세 개의 타입

| 표기 | 타입 | 정체 |
|---|---|---|
| `@Namespace private var animation` | — | 선언 |
| `animation` | `Namespace.ID` | `wrappedValue`. `in:`에 넘기는 값 |
| `_animation` | `Namespace` | 컴파일러가 만든 저장 프로퍼티 |

`animation`을 그냥 쓰면 `Namespace.ID`가 나오는 이유는 `wrappedValue`의 타입이 `Namespace.ID`이기 때문이다. 래퍼 자체(`Namespace`)와 그 안의 값(`Namespace.ID`)이 다른 타입이라는 점이 `@State`와 같은 구조다. `_`·`$`·`wrappedValue`의 관계는 [`@State`와 `_viewModel` 문서](./state-property-wrapper-backing-storage.md)에 정리되어 있다.

`Namespace`는 `DynamicProperty`를 따르므로 **뷰가 다시 만들어져도 같은 값이 유지**된다. 그래서 `@State`처럼 뷰 프로퍼티로 선언해야 하고, 함수 안의 지역 변수로 만들면 안 된다.

### `matchedGeometryEffect`가 실제로 하는 일

시그니처는 이렇다.

```swift
nonisolated func matchedGeometryEffect<ID>(
    id: ID,
    in namespace: Namespace.ID,
    properties: MatchedGeometryProperties = .frame,
    anchor: UnitPoint = .center,
    isSource: Bool = true
) -> some View where ID : Hashable
```

동작의 핵심은 공식 문서의 이 문단이다.

> If inserting a view in the same transaction that another view with the same key is removed, the system will interpolate their frame rectangles in window space to make it appear that there is a single view moving from its old position to its new position.

풀어 쓰면 이렇다.

```text
한 번의 transaction(= withAnimation 블록) 안에서
  같은 (namespace, id)를 가진 뷰 하나가 사라지고
  같은 (namespace, id)를 가진 뷰 하나가 새로 삽입되면
        ↓
두 뷰의 프레임 사각형을 윈도우 좌표계에서 보간한다
        ↓
하나의 뷰가 이동한 것처럼 보인다
```

이 코드에서 탭을 누르면 실제로 이런 일이 벌어진다.

```swift
.onTapGesture {
    withAnimation(.snappy) {
        self.selectedTab = tab      // ← 이 한 줄이 transaction이다
    }
}
```

`selectedTab`이 바뀌면 `if selectedTab == tab` 조건 때문에 **이전 탭의 밑줄은 제거되고 새 탭의 밑줄이 삽입된다.** 둘이 같은 `(animation, "selected_tab")`을 가졌으므로 SwiftUI가 "밑줄 하나가 옆으로 미끄러졌다"고 처리한다.

`withAnimation`으로 감싸지 않으면 보간할 애니메이션 자체가 없어 밑줄이 툭 튄다. [암시적·명시적 애니메이션 문서](./implicit-vs-explicit-animation.md)와 이어진다.

### 꼭 알아야 할 제약 — source는 정확히 하나

문서가 명시적으로 경고한다.

> If the number of currently-inserted views in the group with `isSource = true` is not exactly one results are undefined, due to it not being clear which is the source view.

같은 `(namespace, id)`를 가진 `isSource: true` 뷰가 **둘 이상 화면에 동시에 있으면 동작이 정의되지 않는다.** 이 코드가 안전한 이유는 `if selectedTab == tab` 때문에 **항상 하나만 존재**하기 때문이다. 조건을 빼고 `ForEach`의 모든 항목에 붙이면 곧바로 깨진다.

### 기하만 잇는다, 그리기는 잇지 않는다

또 하나 중요한 문장.

> the `matchedGeometryEffect()` modifier only arranges for the geometry of the views to be linked, not their rendering.

즉 **위치·크기만** 이어 준다. 색이 부드럽게 변하거나 모양이 morph 되는 것은 별개다. 이 코드에서 밑줄 색이 탭마다 달라지는데, 색 전환은 `matchedGeometryEffect`가 아니라 `foregroundStyle`에 `withAnimation`이 걸려서 되는 것이다.

`ReusableSegmentedControl` 쪽은 `Capsule()`을, 주석 처리된 `customSegmentedControl` 쪽은 `RoundedRectangle`을 쓰는데, **모양이 다른 뷰끼리도 짝을 맺을 수 있다.** 프레임만 보간하기 때문이다.

### `properties`로 무엇을 이을지 고르기

기본값은 `.frame`이고, 더 잘게 고를 수 있다.

```swift
.matchedGeometryEffect(id: "selected_tab", in: animation, properties: .position)
.matchedGeometryEffect(id: "selected_tab", in: animation, properties: .size)
.matchedGeometryEffect(id: "selected_tab", in: animation, properties: .frame)  // position + size
```

| 값 | 잇는 것 |
|---|---|
| `.position` | 위치만 |
| `.size` | 크기만 |
| `.frame` | 둘 다 (기본값) |

크기는 그대로 두고 위치만 미끄러뜨리고 싶으면 `.position`을 쓴다.

### `isSource`로 한쪽을 기준으로 삼기

한 뷰를 **기하의 공급자**로, 다른 뷰를 **따라가는 쪽**으로 고정할 수도 있다.

```swift
// 숨어 있는 원본이 크기를 정하고
SourceView()
    .matchedGeometryEffect(id: "hero", in: animation, isSource: true)

// 실제로 보이는 쪽이 그 크기를 따라간다
DisplayView()
    .matchedGeometryEffect(id: "hero", in: animation, isSource: false)
```

이 코드에서는 둘 다 기본값(`true`)이지만, 동시에 하나만 존재하므로 문제가 없다.

### 자식 뷰에 namespace를 넘기기

`Namespace.ID`는 그냥 값이므로 파라미터로 전달할 수 있다. 부모와 자식에 걸친 전환(카드 → 상세 화면)을 만들 때 이렇게 쓴다.

```swift
struct ParentView: View {
    @Namespace private var animation

    var body: some View {
        if isExpanded {
            DetailView(namespace: animation)
        } else {
            CardView(namespace: animation)
        }
    }
}

struct CardView: View {
    let namespace: Namespace.ID    // @Namespace가 아니라 Namespace.ID를 받는다
    // ...
}
```

**자식에서 `@Namespace`를 새로 선언하면 안 된다.** 범위가 달라져 짝이 맺히지 않는다. 받을 때는 `let namespace: Namespace.ID`다.

### `@Namespace`가 쓰이는 다른 자리

기하 연결 말고도 범위가 필요한 API가 몇 개 있다.

| API | 용도 | iOS |
|---|---|---|
| `matchedGeometryEffect(id:in:)` | 두 뷰의 프레임 보간 | 14 |
| `prefersDefaultFocus(_:in:)` / `focusScope(_:)` | 포커스 기본값 지정 | 14 |
| `navigationTransition(.zoom(sourceID:in:))` | 화면 전환 zoom 효과 | 18 |
| `matchedTransitionSource(id:in:)` | 위 전환의 출발점 지정 | 18 |

iOS 18부터는 화면 전환(`NavigationStack` push, sheet)에 `zoom` 전환이 생겼는데, 여기도 `@Namespace`를 쓴다. 세그먼트 컨트롤 같은 **한 화면 안의 이동**은 `matchedGeometryEffect`가 맞고, **화면과 화면 사이**는 `navigationTransition` 쪽이 맞다.

### 이 코드에 적용하면

```swift
@Namespace private var animation
```

- `SegmentedControlSwiftUI` 인스턴스마다 하나씩 생기는 **고유한 범위**다.
- `matchedGeometryEffect(id: "selected_tab", in: animation)`의 `in:`에만 쓰인다.
- 탭을 누르면 밑줄이 **제거 + 삽입**되지만, 같은 `(범위, id)`라서 **하나가 옆으로 미끄러지는 것처럼** 보인다.
- `if selectedTab == tab` 덕분에 source가 항상 하나라 정의되지 않은 동작에 빠지지 않는다.
- `ReusableSegmentedControl`도 자기 `@Namespace`를 따로 갖고 `id: "reusable_segment_id"`를 쓰므로, 두 컨트롤이 함께 있어도 섞이지 않는다.

`@Namespace`를 지우면 `in:`에 넘길 값이 없어 **컴파일이 안 된다.** 반대로 `matchedGeometryEffect`만 지우면 컴파일은 되지만 밑줄이 애니메이션 없이 툭툭 튄다.

## 체크리스트

- [ ] `@Namespace`의 `wrappedValue` 타입이 `Namespace.ID`임을 확인한다.
- [ ] `matchedGeometryEffect`를 지우고 밑줄이 어떻게 움직이는지 비교한다.
- [ ] `withAnimation`을 벗기고 애니메이션이 사라지는 것을 확인한다.
- [ ] `if selectedTab == tab` 조건을 빼서 source가 여러 개일 때 어떻게 깨지는지 본다.
- [ ] 두 컨트롤의 `id` 문자열을 같게 바꾸고, namespace가 달라 안 섞이는 것을 확인한다.
- [ ] 반대로 namespace를 하나로 공유하고 id를 같게 만들어 섞이는 것을 재현한다.
- [ ] `properties: .position`과 `.size`를 각각 적용해 차이를 관찰한다.
- [ ] `RoundedRectangle`과 `Capsule`처럼 모양이 다른 두 뷰로 짝을 맺어 본다.
- [ ] 자식 뷰에 `Namespace.ID`를 파라미터로 넘겨 부모-자식 전환을 만들어 본다.
- [ ] iOS 18의 `navigationTransition(.zoom(sourceID:in:))`으로 화면 간 전환을 시도해 본다.

## 공식 참고 자료

- [SwiftUI: Namespace](https://developer.apple.com/documentation/swiftui/namespace)
- [SwiftUI: Namespace.ID](https://developer.apple.com/documentation/swiftui/namespace/id)
- [SwiftUI: matchedGeometryEffect(id:in:properties:anchor:isSource:)](https://developer.apple.com/documentation/swiftui/view/matchedgeometryeffect(id:in:properties:anchor:issource:))
- [SwiftUI: MatchedGeometryProperties](https://developer.apple.com/documentation/swiftui/matchedgeometryproperties)
- [SwiftUI: DynamicProperty](https://developer.apple.com/documentation/swiftui/dynamicproperty)
- [SwiftUI: matchedTransitionSource(id:in:)](https://developer.apple.com/documentation/swiftui/view/matchedtransitionsource(id:in:))
- [SwiftUI: NavigationTransition](https://developer.apple.com/documentation/swiftui/navigationtransition)
- [SwiftUI: withAnimation(_:_:)](https://developer.apple.com/documentation/swiftui/withanimation(_:_:))
