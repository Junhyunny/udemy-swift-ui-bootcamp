# `ZStack`에서 탭이 어디로 가는가 — SwiftUI 히트 테스트와 DOM 이벤트 비교

## 질문이 나온 코드

`chapter-61/chapter-61/ContentView.swift`

```swift
List(news.articles) { article in
    ZStack {
        NavigationLink(value: article.url) {
            EmptyView()
        }
        .opacity(0.0)          // 투명하게 감춘다

        CardView(
            title: article.title,
            desc: article.description ?? "",
            author: article.author ?? "",
            imageURL: article.urlToImage ?? ""
        )
    }
}
```

`CardView`가 `NavigationLink` 위에 겹쳐 있는데, 탭하면 왜 네비게이션이 동작하는가.

## 공부할 내용

### 결론 먼저

- **SwiftUI에는 DOM의 bubbling·capturing 같은 이벤트 전파 모델이 없다.**
- 대신 **히트 테스트(hit testing)** 로 어느 뷰가 탭을 받을지 결정한다.
- 이 코드가 동작하는 이유는 **`List`의 행 전체가 하나의 탭 영역으로 묶이기 때문**이다. `ZStack`의 z 순서 때문이 아니다.
- HTML로 비유하면 `ZStack`보다 **`<a>` 안에 콘텐츠를 넣은 것**에 가깝다.

### DOM 이벤트 모델 — 비교 대상부터

웹의 이벤트는 세 단계로 흐른다.

```text
① Capturing (내려감)   window → document → ... → target
② Target
③ Bubbling (올라감)    target → ... → document → window
```

핵심 성질이 이렇다.

- **하나의 이벤트가 여러 요소를 거친다**
- 각 요소가 리스너를 붙여 관찰할 수 있다
- `stopPropagation()`으로 전파를 끊을 수 있다
- `pointer-events: none`으로 특정 요소를 통과시킬 수 있다
- z-index가 높은 요소가 이벤트를 먼저 받는다

질문의 예상("위의 CardView만 클릭되고 하단 NavigationLink는 안 될 것 같다")은 **DOM 모델에서는 맞다.** 위에 덮인 요소가 이벤트를 가로채기 때문이다.

### SwiftUI는 다르다 — 히트 테스트

SwiftUI에는 전파 단계가 없다. 대신 이런 순서로 처리된다.

```text
① 탭 발생 → 좌표를 얻는다
② 뷰 계층을 위(앞)에서부터 훑으며 그 좌표를 포함하는 뷰를 찾는다
③ 제스처가 붙어 있고 히트 테스트를 허용하는 뷰를 선택
④ 그 뷰의 제스처 핸들러를 실행
```

**한 번의 탭은 원칙적으로 하나의 제스처로 간다.** 여러 뷰가 순차적으로 받는 개념이 없다.

DOM 개념과 대응시켜 보면 이렇다.

| DOM | SwiftUI | 비고 |
| --- | --- | --- |
| Bubbling | **없음** | 상위 뷰로 자동 전파되지 않는다 |
| Capturing | **없음** | — |
| `stopPropagation()` | 불필요 | 애초에 전파가 없다 |
| `pointer-events: none` | `.allowsHitTesting(false)` | 대응 개념 |
| z-index | `ZStack` 순서 | 나중에 선언한 것이 위 |
| 이벤트 위임 | `.contentShape()` + 컨테이너 제스처 | 발상이 유사 |
| `preventDefault()` | 대응물 없음 | 기본 동작 개념이 다르다 |

### 그럼 이 코드는 왜 동작하나

**핵심은 `List`다.** `ZStack`의 순서 때문이 아니다.

`List`의 행 안에 `NavigationLink`가 있으면, SwiftUI는 **행 전체를 하나의 탭 가능한 영역**으로 만든다. iOS 리스트의 표준 동작이다 — 셀 어디를 눌러도 상세 화면으로 가고, 오른쪽에 chevron(`>`)이 표시된다.

```text
List의 행
┌────────────────────────────────────┐
│  ← 이 영역 전체가 NavigationLink   │  ⟩
│     안에 CardView가 그려진다       │
└────────────────────────────────────┘
```

즉 `ZStack`에 나란히 둔 두 뷰가 **경쟁하는 구조가 아니다.** `List`가 행에서 `NavigationLink`를 찾아내 행 전체에 연결하고, `CardView`는 그 안에 표시되는 내용이 된다.

HTML로 비유하면 이렇다.

```html
<!-- ZStack으로 겹친 것처럼 보이지만 -->
<div style="position:relative">
  <a href="..." style="opacity:0"></a>
  <div class="card">...</div>
</div>

<!-- 실제 동작은 이것에 가깝다 -->
<a href="...">
  <div class="card">...</div>
</a>
```

`.opacity(0.0)`을 준 이유도 여기서 나온다. `NavigationLink`가 `EmptyView`를 라벨로 갖고 있어 보일 것이 없지만, 링크임을 나타내는 chevron이나 기본 스타일이 나타날 수 있다. 투명하게 만들어 `CardView`만 보이게 하는 것이다.

**중요한 점: `.opacity(0.0)`은 탭을 막지 않는다.**

투명도는 **그리기에만 영향을 주고 히트 테스트에는 영향이 없다.** `opacity(0)`인 뷰도 탭을 받는다. DOM에서 `opacity: 0`인 요소가 여전히 클릭되는 것과 같다. (`visibility: hidden`이나 `display: none`과는 다르다.)

탭을 막으려면 별도 modifier가 필요하다.

```swift
.allowsHitTesting(false)     // 이 뷰와 하위는 탭을 받지 않는다
```

### `ZStack`만 있을 때는 어떻게 되나

`List` 없이 `ZStack`만 쓰면 질문의 예상대로 동작한다.

```swift
ZStack {
    Button("아래") { print("아래") }
    Color.blue.frame(width: 100, height: 100)   // 위에 덮는다
}
```

파란 사각형을 탭하면 **아무 일도 일어나지 않는다.** `Color`가 히트 테스트를 받아 버리고, 제스처가 없으므로 탭이 소비된다. 아래 `Button`으로 내려가지 않는다 — **DOM의 bubbling과 달리 위로도 아래로도 전파되지 않는다.**

이때 아래로 통과시키려면 이렇게 한다.

```swift
ZStack {
    Button("아래") { print("아래") }
    Color.blue
        .frame(width: 100, height: 100)
        .allowsHitTesting(false)      // 통과시킨다
}
```

### 히트 테스트를 제어하는 modifier들

**① `allowsHitTesting(_:)`**

```swift
nonisolated func allowsHitTesting(_ enabled: Bool) -> some View
```

`false`면 이 뷰와 **하위 전체**가 탭을 받지 않는다. DOM의 `pointer-events: none`에 대응한다.

**② `contentShape(_:eoFill:)`**

```swift
nonisolated func contentShape<S>(_ shape: S, eoFill: Bool = false) -> some View where S : Shape
```

> A view that uses the given shape for hit testing.

**히트 테스트에 쓸 모양을 지정한다.** [chapter-53의 리뷰에서 지적된 문제](./phase-animator-parameters-and-phase-types.md)가 이것이었다. 배경이 없는 `VStack`은 투명한 부분에서 탭이 먹지 않는데, `.contentShape(Rectangle())`을 주면 사각형 전체가 탭 영역이 된다.

```swift
VStack {
    Text("제목")
    Spacer()
}
.contentShape(Rectangle())    // 빈 공간도 탭 가능
.onTapGesture { ... }
```

**③ 제스처 우선순위 modifier**

여러 제스처가 겹칠 때 관계를 정한다.

| modifier | 동작 |
| --- | --- |
| `gesture(_:)` | 기본 — 자식 제스처가 우선 |
| `highPriorityGesture(_:)` | 이 제스처를 자식보다 먼저 |
| `simultaneousGesture(_:)` | **동시에 인식** |

`simultaneousGesture`가 DOM의 전파에 가장 가까운 동작을 만든다.

> Use this method when you need to define and process a view specific gesture simultaneously with the same priority as the view's existing gestures.

Apple 문서의 예제를 보면 하트 이미지를 탭했을 때 **두 개의 메시지**가 출력된다 — 이미지 자신의 핸들러와 바깥 `VStack`의 핸들러가 모두 실행된다.

```swift
VStack(spacing: 25) {
    Image(systemName: "heart.fill")
        .onTapGesture { print("Gesture on image.") }
    Rectangle().fill(Color.blue)
}
.simultaneousGesture(TapGesture().onEnded { print("Gesture on VStack.") })
```

**즉 SwiftUI에서 "전파"처럼 보이는 동작을 원하면 명시적으로 요청해야 한다.** 기본값은 전파하지 않는 것이다.

### 투명 뷰와 히트 테스트 규칙 정리

| 상태 | 탭을 받나 |
| --- | --- |
| `opacity(0.0)` | **받는다** |
| `opacity(0.5)` | 받는다 |
| `Color.clear` | **받는다** (배경이 있는 뷰로 취급) |
| `EmptyView()` | 받지 않는다 (실체가 없다) |
| 배경 없는 `VStack`의 빈 공간 | **받지 않는다** — `contentShape` 필요 |
| `allowsHitTesting(false)` | 받지 않는다 |
| `hidden()` | 받지 않는다 (레이아웃 공간은 차지) |
| `disabled(true)` | 받지 않는다 |

`Color.clear`가 탭을 받는다는 점이 유용하다. [PreferenceKey 문서](./preference-key-and-onpreferencechange.md)에서 측정용으로 쓴 `Color.clear`와 달리, 탭 영역을 만드는 용도로도 쓰인다.

```swift
ZStack {
    Color.clear                      // 전체 영역 탭 가능
    Text("내용")
}
.onTapGesture { ... }
```

### 이 코드의 대안 — 더 단순한 방법

`ZStack` + 투명 `NavigationLink` 패턴은 **`NavigationView` 시절의 관용구**다. 그때는 `NavigationLink`의 라벨을 커스터마이징하기 어려워 이런 우회가 필요했다.

**현행 API에서는 그냥 라벨에 넣으면 된다.**

```swift
List(news.articles) { article in
    NavigationLink(value: article.url) {
        CardView(
            title: article.title,
            desc: article.description ?? "",
            author: article.author ?? "",
            imageURL: article.urlToImage ?? ""
        )
    }
}
```

`ZStack`과 `.opacity(0.0)`이 모두 사라진다. `NavigationLink`의 라벨 클로저에 어떤 뷰든 넣을 수 있으므로 카드 전체가 링크가 된다. [NavigationLink 두 방식](./navigation-link-two-styles-mixed.md)에서 다룬 값 기반 링크의 라벨 클로저다.

리스트의 기본 chevron이나 강조 스타일이 싫다면 이렇게 조절한다.

```swift
.listRowSeparator(.hidden)
.listRowInsets(EdgeInsets())
.buttonStyle(.plain)
```

### 정리

```text
SwiftUI에는 bubbling / capturing이 없다
  히트 테스트로 "어느 뷰가 받을지" 하나를 정한다
  기본적으로 전파하지 않는다
  전파처럼 만들려면 simultaneousGesture로 명시

이 코드가 동작하는 이유
  ZStack의 z 순서가 아니라, List가 행 전체를
  NavigationLink 영역으로 묶기 때문
  HTML의 <a><div>...</div></a> 구조에 가깝다

opacity(0.0)은 탭을 막지 않는다
  그리기에만 영향. 막으려면 allowsHitTesting(false)

DOM ↔ SwiftUI 대응
  pointer-events: none  →  allowsHitTesting(false)
  z-index              →  ZStack 순서
  이벤트 위임           →  contentShape + 컨테이너 제스처
  bubbling             →  대응물 없음 (simultaneousGesture로 유사 구현)
```

## 학습 체크리스트

- [ ] 카드의 여러 위치(이미지, 제목, 빈 공간)를 탭해 모두 네비게이션되는지 확인한다.
- [ ] `ZStack`을 없애고 `NavigationLink`의 라벨에 `CardView`를 직접 넣어 본다.
- [ ] `.opacity(0.0)`을 `1.0`으로 바꿔 `NavigationLink`가 실제로 무엇을 그리는지 본다.
- [ ] `List`를 `VStack`으로 바꿔 동작이 달라지는지 확인한다.
- [ ] `ZStack { Button("아래") { }; Color.blue }`를 만들어 버튼이 눌리지 않는 것을 확인한다.
- [ ] 위 코드의 `Color.blue`에 `.allowsHitTesting(false)`를 붙여 통과되는지 확인한다.
- [ ] `opacity(0.0)`인 뷰가 여전히 탭을 받는 것을 직접 확인한다.
- [ ] 배경 없는 `VStack`에 `onTapGesture`를 붙이고 빈 공간이 안 먹는 것을 확인한다.
- [ ] 위에 `.contentShape(Rectangle())`을 추가해 해결되는지 확인한다.
- [ ] `simultaneousGesture`로 자식과 부모 제스처가 모두 실행되게 만들어 본다.
- [ ] Apple 문서의 `SimultaneousGestureExample`을 그대로 실행해 두 메시지를 확인한다.
- [ ] `highPriorityGesture`로 부모가 자식보다 먼저 받게 해 본다.
- [ ] `Color.clear`와 `EmptyView()`의 탭 수신 차이를 실험한다.
- [ ] `disabled(true)`와 `allowsHitTesting(false)`의 차이를 비교한다.

## 공식 참고 자료

- [Apple: view.allowsHitTesting(_:)](https://developer.apple.com/documentation/swiftui/view/allowshittesting(_:))
- [Apple: view.contentShape(_:eoFill:)](https://developer.apple.com/documentation/swiftui/view/contentshape(_:eofill:))
- [Apple: view.simultaneousGesture(_:including:)](https://developer.apple.com/documentation/swiftui/view/simultaneousgesture(_:including:))
- [Apple: view.highPriorityGesture(_:including:)](https://developer.apple.com/documentation/swiftui/view/highprioritygesture(_:including:))
- [Apple: view.gesture(_:including:)](https://developer.apple.com/documentation/swiftui/view/gesture(_:including:))
- [Apple: GestureMask](https://developer.apple.com/documentation/swiftui/gesturemask)
- [Apple: view.onTapGesture(count:perform:)](https://developer.apple.com/documentation/swiftui/view/ontapgesture(count:perform:))
- [Apple: ZStack](https://developer.apple.com/documentation/swiftui/zstack)
- [Apple: NavigationLink](https://developer.apple.com/documentation/swiftui/navigationlink)
- [Apple: List](https://developer.apple.com/documentation/swiftui/list)
- [Apple: Gestures](https://developer.apple.com/documentation/swiftui/gestures)
- [Apple: view.hidden()](https://developer.apple.com/documentation/swiftui/view/hidden())
- [Apple: view.disabled(_:)](https://developer.apple.com/documentation/swiftui/view/disabled(_:))
