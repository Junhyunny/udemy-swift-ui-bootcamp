# deprecated된 `NavigationLink` 이니셜라이저와 최신 대안

`NavigationStack`이 `NavigationView`를 어떻게 대체했는지는 [별도 문서](./navigation-stack-vs-navigation-view.md)에 정리했다. 이 문서는 **구형 `NavigationLink` 이니셜라이저 두 개**를 다룬다.

## 질문이 나온 코드

`chapter-58/chapter-58/ContentView.swift`

```swift
// ① Bool로 제어
NavigationLink(
    "Click Me",
    destination: NavigationDestinationView(counter: counter),
    isActive: $triggerAnimation
)
```

```swift
// ② tag와 selection으로 제어
NavigationLink(
    "View 1",
    destination: Text("View 1"),
    tag: 1,
    selection: $selected
)
```

경고 메시지는 이렇게 나온다.

```
'init(_:destination:isActive:)' was deprecated in iOS 16.0:
use NavigationLink(value:label:), or navigationDestination(isPresented:destination:),
inside a NavigationStack or NavigationSplitView
```

## 공부할 내용

### 언제 deprecated 됐나

두 이니셜라이저 모두 같은 이력을 갖는다.

| 이니셜라이저 | 도입 | deprecated |
| --- | --- | --- |
| `init(_:destination:isActive:)` | iOS 13.0 | **iOS 16.0** |
| `init(_:destination:tag:selection:)` | iOS 13.0 | **iOS 16.0** |

SwiftUI 첫 버전부터 있었고, `NavigationStack`이 등장한 iOS 16에서 함께 정리됐다. 같은 파일의 `NavigationView`도 같은 흐름이다.

### 두 방식이 하던 일

**① `isActive:` — `Bool` 하나로 한 화면 제어**

```swift
@State private var triggerAnimation = false

NavigationLink("Click Me", destination: DetailView(), isActive: $triggerAnimation)

Button("Trigger Navigation") {
    triggerAnimation.toggle()      // 코드로 화면 전환
}
```

`true`면 밀어 넣고 `false`면 뺀다. 코드로 네비게이션을 제어할 수 있는 유일한 수단이었다.

**② `tag:selection:` — 여러 목적지 중 하나 선택**

```swift
@State private var selected: Int? = 0

NavigationLink("View 1", destination: Text("View 1"), tag: 1, selection: $selected)
NavigationLink("View 2", destination: Text("View 2"), tag: 2, selection: $selected)
NavigationLink("View 3", destination: DestView(title: "View 3"), tag: 3, selection: $selected)

Button("Trigger 1") { selected = 1 }
Button("Trigger 2") { selected = 2 }
```

`selection`이 어떤 `tag`와 일치하면 그 링크의 목적지가 열린다. 여러 링크가 하나의 상태를 공유하는 구조다. `isActive:`의 확장판이라고 보면 된다.

### 왜 없애나 — 구조적 한계

**① 화면마다 상태가 하나씩 필요하다**

`isActive:` 방식은 화면 하나에 `Bool` 하나다. 3단계 깊이면 `@State`가 세 개다.

```swift
@State private var showA = false
@State private var showB = false
@State private var showC = false
```

`tag:selection:`은 조금 낫지만 여전히 **한 단계**만 다룬다.

**② 현재 깊이를 알 수 없다**

`Bool` 몇 개를 봐도 "지금 몇 단계 들어와 있는가"를 알 방법이 없다.

**③ 여러 단계를 한 번에 조작할 수 없다**

"3단계로 바로 진입" 또는 "루트까지 한 번에 돌아가기"를 표현할 방법이 없다. 딥링크 처리가 특히 까다롭다.

**④ 목적지를 미리 만든다**

```swift
NavigationLink("Click Me", destination: NavigationDestinationView(counter: counter), ...)
```

`destination:`에 뷰 인스턴스를 **직접 넘기므로** 링크를 그리는 시점에 목적지도 만들어진다. 목록이 100개면 목적지도 100개다.

**⑤ `selection`이 옵셔널이라 상태가 애매하다**

`Int?`의 `nil`이 "선택 없음"인데, 예제는 초기값을 `0`으로 두었다. `0`은 어떤 `tag`와도 일치하지 않아 결과적으로 동작하지만, `nil`이 자연스러운 표현이다.

`path` 배열 하나가 이 문제를 모두 해결한다. [`NavigationPath`와 타입 배열 문서](./navigation-path-and-typed-array.md) 참조.

### 대안 ① `navigationDestination(isPresented:)` — 최소 수정

경고가 제시한 두 방법 중 첫 번째다. `Bool` 제어 구조를 유지하므로 수정이 가볍다.

```swift
nonisolated func navigationDestination<V>(
    isPresented: Binding<Bool>,
    @ViewBuilder destination: () -> V
) -> some View where V : View
```

`isActive:` 코드를 이렇게 옮긴다.

```swift
NavigationStack {
    VStack {
        Text("Hello World").font(.largeTitle)
        Button("Increase count") { counter += 1 }
            .buttonStyle(.bordered)

        Button("Trigger Navigation") {
            triggerAnimation = true
        }
    }
    .navigationDestination(isPresented: $triggerAnimation) {
        NavigationDestinationView(counter: counter)
    }
    .navigationTitle("NavigationLink Example")
}
```

**`NavigationLink`가 사라지고 버튼 + modifier가 된다.** 예제에서 "Click Me" 링크와 "Trigger Navigation" 버튼이 같은 상태를 공유했으니 하나로 합쳐진다.

Apple이 이 API의 위치를 분명히 한다.

> **In general, favor binding a path to a navigation stack for programmatic navigation.** Add this view modifier to a view inside a `NavigationStack` to programmatically push a single view onto the stack. **This is useful for building components that can push an associated view.**

즉 `isPresented:`는 **재사용 컴포넌트가 자기 화면을 밀어 넣는** 특수한 경우용이고, 일반적인 네비게이션은 `path`를 쓰라는 뜻이다.

### 대안 ② `NavigationLink(value:)` + `path` — 권장 방식

`tag:selection:`을 대체하기에도 이쪽이 자연스럽다.

```swift
@State private var path: [Int] = []

NavigationStack(path: $path) {
    VStack {
        NavigationLink("View 1", value: 1)
        NavigationLink("View 2", value: 2)
        NavigationLink("View 3", value: 3)
    }
    .buttonStyle(.bordered)

    HStack {
        Button("Trigger 1") { path.append(1) }
        Button("Trigger 2") { path.append(2) }
        Button("Trigger 3") { path.append(3) }
    }
    .buttonStyle(.borderedProminent)
    .navigationDestination(for: Int.self) { tag in
        switch tag {
        case 1: Text("View 1").navigationBarBackButtonHidden()
        case 2: Text("View 2")
        default: DestView(title: "View \(tag)")
        }
    }
    .navigationTitle("NavigationLink Example")
}
```

**무엇이 좋아지나**

- `tag`/`selection` 쌍이 사라지고 **값 하나**로 통일된다
- 링크 탭과 버튼이 **같은 경로**(`path`)를 쓴다
- `path.count`로 현재 깊이를 알 수 있다
- `path = []`로 루트까지 한 번에 돌아간다
- `path.append(1); path.append(2)`로 여러 단계를 미리 쌓을 수 있다
- 목적지가 **탭할 때** 만들어진다

값과 목적지가 연결되는 원리는 [별도 문서](./navigation-link-value-and-destination.md)에 정리했다.

`enum`으로 정리하면 더 명확해진다.

```swift
enum Route: Hashable {
    case view1, view2, view3
}

@State private var path: [Route] = []

.navigationDestination(for: Route.self) { route in
    switch route {
    case .view1: Text("View 1")
    case .view2: Text("View 2")
    case .view3: DestView(title: "View 3")
    }
}
```

`switch`에서 case 누락을 컴파일러가 잡아 준다. [enum과 Hashable](./enum-hashable-conformance.md) 참조.

### 대응표

| 구형 (iOS 16 deprecated) | 최신 |
| --- | --- |
| `NavigationView` | `NavigationStack` / `NavigationSplitView` |
| `NavigationLink(_:destination:)` | `NavigationLink(value:)` + `navigationDestination(for:)` |
| `NavigationLink(_:destination:isActive:)` | `navigationDestination(isPresented:)` 또는 `path` |
| `NavigationLink(_:destination:tag:selection:)` | `NavigationLink(value:)` + `path` |
| `@State var isActive: Bool` 여러 개 | `@State var path: [Route]` 하나 |

### 주의할 점

**① `navigationDestination`은 `NavigationStack` 안에서만 동작한다**

예제는 아직 `NavigationView`를 쓰고 있으므로 함께 바꿔야 한다.

```swift
NavigationView {   // → NavigationStack {
```

**② lazy 컨테이너 안에 넣지 않는다**

> Do not put a navigation destination modifier inside a "lazy" container, like `List` or `LazyVStack`. These containers create child views only when needed to render on screen.

**③ deprecated는 "즉시 사용 불가"가 아니다**

경고가 뜨지만 동작한다. 언젠가 제거될 수 있다는 예고다. 강의 예제를 따라가는 중이라면 그대로 두어도 무방하고, 실무 코드라면 옮기는 편이 낫다.

**④ 배포 타겟이 iOS 16 이상이어야 대안을 쓸 수 있다**

버전 확인 방법은 [호환성 문서](./swift-ios-device-compatibility.md)에 정리했다.

### 이 예제에서 눈여겨볼 것

`navigationBarBackButtonHidden()`이 여러 곳에 쓰였다.

```swift
Text("View 1").navigationBarBackButtonHidden()
```

기본 back 버튼을 감추는 modifier다. 그러면 **뒤로 갈 방법이 없어지므로** 직접 제공해야 한다. `DestView`가 그 답을 보여 준다.

```swift
struct DestView: View {
    @Environment(\.dismiss) var dismiss
    var title: String
    var body: some View {
        Text(title)
            .navigationBarBackButtonHidden()
            .onTapGesture { _ in
                dismiss()
            }
    }
}
```

`\.dismiss`가 `NavigationStack`에서 **pop 역할**을 한다. 자세한 내용은 [`@Environment` 문서](./environment-property-wrapper.md)에 정리했다.

`onTapGesture { _ in ... }`가 컴파일되는 것도 짚어둘 만하다. `onTapGesture`에는 두 형태가 있다.

```swift
func onTapGesture(count: Int = 1, perform action: @escaping () -> Void) -> some View
func onTapGesture(count: Int = 1, coordinateSpace: some CoordinateSpaceProtocol = .local,
                  perform action: @escaping (CGPoint) -> Void) -> some View
```

`{ _ in }`은 두 번째(탭 좌표를 받는 버전)로 해석된다. 좌표를 쓰지 않으니 `{ }`로 써도 되고, 그러면 첫 번째 형태가 선택된다.

## 학습 체크리스트

- [ ] 경고 메시지를 클릭해 Xcode가 제안하는 수정안을 확인한다.
- [ ] `isActive:` 코드를 `navigationDestination(isPresented:)`로 옮겨 본다.
- [ ] 그 과정에서 `NavigationView`를 `NavigationStack`으로 바꿔야 함을 확인한다.
- [ ] `tag:selection:` 세 개를 `NavigationLink(value:)` + `path`로 바꿔 본다.
- [ ] `path.count`를 화면에 표시해 현재 깊이를 확인한다.
- [ ] `path.append(1)`을 두 번 호출해 두 단계를 한 번에 쌓아 본다.
- [ ] `path = []`로 루트까지 한 번에 돌아가는 버튼을 만든다.
- [ ] `selected` 초기값을 `0`에서 `nil`로 바꿔도 동작하는지 확인한다.
- [ ] `enum Route`를 만들어 `switch`로 목적지를 분기해 본다.
- [ ] `navigationBarBackButtonHidden()`을 지우고 기본 back 버튼이 돌아오는지 확인한다.
- [ ] `onTapGesture { _ in }`을 `onTapGesture { }`로 바꿔도 컴파일되는지 확인한다.
- [ ] `dismiss()`가 시트가 아닌 `NavigationStack`에서도 pop으로 동작하는지 확인한다.
- [ ] 배포 타겟을 iOS 15로 낮추고 `navigationDestination`이 에러를 내는지 본다.

## 공식 참고 자료

- [Apple: NavigationLink.init(_:destination:isActive:) (deprecated)](https://developer.apple.com/documentation/swiftui/navigationlink/init(_:destination:isactive:))
- [Apple: NavigationLink.init(_:destination:tag:selection:) (deprecated)](https://developer.apple.com/documentation/swiftui/navigationlink/init(_:destination:tag:selection:))
- [Apple: view.navigationDestination(isPresented:destination:)](https://developer.apple.com/documentation/swiftui/view/navigationdestination(ispresented:destination:))
- [Apple: view.navigationDestination(for:destination:)](https://developer.apple.com/documentation/swiftui/view/navigationdestination(for:destination:))
- [Apple: NavigationLink](https://developer.apple.com/documentation/swiftui/navigationlink)
- [Apple: NavigationStack](https://developer.apple.com/documentation/swiftui/navigationstack)
- [Apple: Migrating to new navigation types](https://developer.apple.com/documentation/swiftui/migrating-to-new-navigation-types)
- [Apple: view.navigationBarBackButtonHidden(_:)](https://developer.apple.com/documentation/swiftui/view/navigationbarbackbuttonhidden(_:))
- [Apple: DismissAction](https://developer.apple.com/documentation/swiftui/dismissaction)
- [Apple: view.onTapGesture(count:perform:)](https://developer.apple.com/documentation/swiftui/view/ontapgesture(count:perform:))
- [Apple: view.onTapGesture(count:coordinateSpace:perform:)](https://developer.apple.com/documentation/swiftui/view/ontapgesture(count:coordinatespace:perform:))
