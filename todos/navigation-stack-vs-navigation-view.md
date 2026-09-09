# `NavigationStack`은 언제 등장했고 `NavigationView`와 무엇이 다른가

`NavigationStack`의 기본 역할과 `navigationTitle`을 붙이는 위치는 [별도 문서](./navigation-stack-and-title.md)에 정리했다. 이 문서는 **구형 API와의 관계**를 다룬다.

## 질문이 나온 코드

`chapter-57/chapter-57/ContentView.swift`

```swift
// NavigationView {
//     List {
//         Text("Mastering SwiftUI")
//         Text("Mastering iOS machine learning")
//     }
//     .navigationTitle(Text("DevTechie courses"))
// }
NavigationStack(path: $path) {
    // ...
}
```

## 공부할 내용

### 먼저 — "Swift 몇"이 아니라 "iOS 몇"이다

[`ImageResource` 문서](./image-resource-and-asset-symbols.md)에서도 나온 구분이다. SwiftUI 타입의 등장 시점은 **Swift 언어 버전이 아니라 OS·SDK 버전**으로 정해진다.

| 타입 | 도입 | 상태 |
| --- | --- | --- |
| `NavigationView` | **iOS 13.0** (2019) | **iOS 27.0에서 deprecated** |
| `NavigationStack` | **iOS 16.0** (2022) | 현행 |
| `NavigationSplitView` | iOS 16.0 | 현행 |
| `NavigationPath` | iOS 16.0 | 현행 |

`NavigationView`는 SwiftUI 첫 버전부터 있었고, 3년 뒤 iOS 16에서 `NavigationStack`과 `NavigationSplitView` 둘로 나뉘어 대체됐다. 버전 확인 방법 전반은 [호환성 자료 문서](./swift-ios-device-compatibility.md)에 정리했다.

### 왜 둘로 나뉘었나 — `NavigationView`의 근본 문제

`NavigationView` 하나가 **두 가지 다른 UI**를 겸했다.

> On iPadOS and macOS, the destination content appears in the next column. Other platforms push a new view onto the stack.

같은 코드가 iPhone에서는 화면을 쌓고(stack), iPad·Mac에서는 컬럼을 나눠 보여 줬다(split). 어느 쪽으로 동작할지가 **플랫폼과 스타일 설정에 따라 암묵적으로 결정**되어 예측이 어려웠다.

그래서 iOS 16에서 의도를 명시적으로 나누었다.

```text
NavigationView (하나가 두 역할)
        ↓
NavigationStack       — 화면을 쌓는다 (iPhone 스타일)
NavigationSplitView   — 컬럼으로 나눈다 (iPad·Mac 스타일)
```

Apple의 마이그레이션 안내가 이 대응을 그대로 보여 준다.

> If your app uses a `NavigationView` that you style using the `.stack` navigation view style, where people navigate by pushing a new view onto a stack, switch to `NavigationStack`.
>
> In particular, stop doing this:
> ```swift
> NavigationView { // This is deprecated.
>     /* content */
> }
> .navigationViewStyle(.stack)
> ```
> Instead, create a navigation stack:
> ```swift
> NavigationStack {
>     /* content */
> }
> ```

두 컬럼짜리는 이렇게 바뀐다.

> Instead of using a two-column `NavigationView`:
> ```swift
> NavigationView { // This is deprecated.
>     /* column 1 */
>     /* column 2 */
> }
> ```
> Create a navigation split view that has explicit sidebar and detail content:
> ```swift
> NavigationSplitView {
>     /* column 1 */
> } detail: {
>     /* column 2 */
> }
> ```

### 가장 큰 변화 — 값 기반 네비게이션

이것이 실질적으로 코드를 바꾼 부분이다.

**`NavigationView` 시절 — 목적지 뷰를 직접 들고 다녔다**

```swift
NavigationView {
    List(model.notes) { note in
        NavigationLink(note.title, destination: NoteEditor(id: note.id))
    }
    Text("Select a Note")
}
```

각 `NavigationLink`가 **목적지 뷰를 직접 갖는다.** 문제가 여기서 나온다.

- 목록의 행이 100개면 `NoteEditor` 100개가 미리 만들어진다. 화면에 하나도 안 보이는데도 그렇다
- 코드에서 "3단계 깊이로 이동하라"를 표현할 방법이 마땅치 않다
- 딥링크로 특정 화면에 바로 진입하기가 까다롭다
- 뒤로 여러 단계를 한 번에 빼기 어렵다

**`NavigationStack` — 값을 넘기고, 목적지는 따로 선언한다**

```swift
NavigationStack {
    List(parks) { park in
        NavigationLink(park.name, value: park)
    }
    .navigationDestination(for: Park.self) { park in
        ParkDetails(park: park)
    }
}
```

링크는 **값만** 넘기고, 그 값을 어떤 뷰로 그릴지는 `navigationDestination`이 한 번만 선언한다. 이 연결 원리는 [별도 문서](./navigation-link-value-and-destination.md)에 정리했다.

### `path` — 네비게이션 상태를 코드가 소유한다

두 번째 큰 변화다.

> By default, a navigation stack manages state to keep track of the views on the stack. However, your code can share control of the state by initializing the stack with a binding to a collection of data values that you create. The stack adds items to the collection as it adds views to the stack and removes items when it removes views.

```swift
@State private var presentedParks: [Park] = []

NavigationStack(path: $presentedParks) { ... }
```

배열을 읽으면 현재 어디에 있는지 알 수 있고, 배열을 바꾸면 화면이 따라온다.

```swift
func showParks() {
    presentedParks = [Park("Yosemite"), Park("Sequoia")]
}
```

> The `showParks` method replaces the stack's display with a view that shows details for Sequoia, the last item in the new `presentedParks` array. Navigating back from that view removes Sequoia from the array, which reveals a view that shows details for Yosemite. **Use a path to support deep links, state restoration, or other kinds of programmatic navigation.**

마지막 문장이 이 기능의 존재 이유를 요약한다. [chapter-51의 딥링크 예제](./deep-link-and-url-scheme.md)에서 `NavigationCoordinator`가 `path.append(Route.test)`를 하던 것이 정확히 이 용법이다. `NavigationView`로는 이런 코드를 쓸 수 없었다.

### 무엇이 좋아졌나

| 항목 | `NavigationView` | `NavigationStack` |
| --- | --- | --- |
| 목적지 생성 시점 | 링크마다 **미리** | **필요할 때** |
| 대량 목록 성능 | 나쁨 | 좋음 |
| 코드로 이동 | 어려움 | `path` 조작 |
| 딥링크 | 까다로움 | 자연스러움 |
| 상태 복원 | 사실상 불가 | `Codable`로 저장·복원 |
| 여러 단계 pop | 어려움 | `path.removeLast(n)` 또는 `path = .init()` |
| 동작 예측 | 플랫폼에 따라 암묵적 | 명시적 |
| 목적지 선언 | 링크마다 반복 | 타입당 한 번 |

### 무엇이 불편해졌나

솔직하게 짚으면 이런 것들이 있다.

**① 개념이 늘었다.** `NavigationLink(destination:)` 하나면 되던 것이 `value:` + `navigationDestination(for:)` 조합이 됐다. 처음 배울 때 연결 관계가 한눈에 안 들어온다.

**② 타입이 `Hashable`이어야 한다.** 값 기반이므로 넘길 타입에 `Hashable` 준수가 필요하다. [enum과 Hashable 문서](./enum-hashable-conformance.md) 참조.

**③ `navigationDestination`의 위치 제약이 있다.**

> Do not put a navigation destination modifier inside a "lazy" container, like `List` or `LazyVStack`. These containers create child views only when needed to render on screen. Add the navigation destination modifier outside these containers so that the navigation stack can always see the destination.

`List` 안에 넣으면 스크롤로 사라진 순간 목적지를 못 찾는다. 실수하기 쉬운 지점이다.

**④ 최소 배포 타겟이 iOS 16이다.** 하위 버전을 지원해야 하면 쓸 수 없다.

**⑤ 두 방식을 섞으면 혼란스럽다.** `NavigationLink(destination:)`도 여전히 동작하므로, 한 프로젝트에 두 스타일이 섞여 들어가기 쉽다.

### 하위 호환성은 지켜졌나

**"기존 코드가 깨졌는가"는 아니다. 하지만 "새 API를 낮은 버전에서 쓸 수 있는가"도 아니다.** 두 방향을 나눠 봐야 한다.

**기존 코드 관점 — 깨지지 않았다**

`NavigationView`는 iOS 16이 나온 뒤에도 계속 동작했다. Apple은 삭제하지 않고 **deprecated 표시**만 했다. 실제로 문서상 deprecation은 iOS 27.0에 와서야 붙었다. 즉 도입(iOS 16)부터 공식 deprecated까지 상당한 유예 기간이 있었다.

deprecated는 "당장 못 쓴다"가 아니라 "경고가 뜨고, 언젠가 사라질 수 있다"는 신호다.

**새 API 관점 — 하위 버전에서는 못 쓴다**

`NavigationStack`은 iOS 16 이상에서만 존재한다. iOS 15를 지원해야 한다면 분기해야 한다.

```swift
if #available(iOS 16.0, *) {
    NavigationStack { content }
} else {
    NavigationView { content }
        .navigationViewStyle(.stack)
}
```

이런 분기는 유지보수가 번거로워서, 실무에서는 **최소 배포 타겟을 iOS 16으로 올리는 시점에 한 번에 마이그레이션**하는 경우가 많다.

Apple의 기준도 그렇다.

> If your app has a minimum deployment target of iOS 16, iPadOS 16, macOS 13, tvOS 16, watchOS 9, or visionOS 1, or later, transition away from using `NavigationView`.

**"최소 배포 타겟이 iOS 16 이상이면 옮겨라"** — 조건이 명확하다.

### 이 예제에서 확인할 것

주석 처리된 `NavigationView` 버전과 아래의 `NavigationStack` 버전을 나란히 보면 차이가 드러난다.

```swift
// 구형 — 목록만 있고, 이동 로직이 없다
NavigationView {
    List {
        Text("Mastering SwiftUI")
        Text("Mastering iOS machine learning")
    }
    .navigationTitle(Text("DevTechie courses"))
}
```

```swift
// 현행 — path로 상태를 소유하고, 값과 목적지를 분리
NavigationStack(path: $path) {
    List {
        NavigationLink(value: "Mastering iOS and UIKit") { ... }
        NavigationLink("Mastering SwiftUI", value: Color.orange)
    }
    .navigationDestination(for: String.self) { ... }
    .navigationDestination(for: Color.self) { ... }
}
```

`navigationDestination`을 **두 개** 붙여 `String`과 `Color`를 각각 처리하는 것도 새 방식이라 가능한 구조다.

> To create a stack that can present more than one kind of view, you can add multiple `navigationDestination(for:destination:)` modifiers inside the stack's view hierarchy, with each modifier presenting a different data type. **The stack matches navigation links with navigation destinations based on their respective data types.**

`NavigationView`에서는 링크마다 목적지를 직접 지정했으니 이런 "타입별 분기"라는 개념 자체가 없었다.

### 마이그레이션 사례 — `chapter-69`의 `TabView` + `NavigationView`

`chapter-69/chapter-69/CourseHome.swift`가 전형적인 구형 구조다.

```swift
TabView {
    NavigationView {
        List(Course.sample) { course in
            ZStack {
                NavigationLink(destination: CourseDetailView(course: course, cart: cart)) {
                    EmptyView()
                }.opacity(0)
                CourseCardView(course: course)
            }
        }
        .navigationTitle("Jun's Courses")
    }
    .tabItem { Label("Courses", systemImage: "list.bullet.circle") }

    NavigationView {
        CartView(cart: cart)
    }
    .tabItem { Label("Cart", systemImage: "cart.circle") }
}
```

**탭마다 `NavigationView`를 하나씩 두는 것 자체는 올바른 구조다.** 각 탭이 독립적인 네비게이션 스택을 가져야 하기 때문이다. 바꿀 것은 컨테이너 이름뿐이다.

```swift
TabView {
    NavigationStack {
        // ...
    }
    .tabItem { Label("Courses", systemImage: "list.bullet.circle") }

    NavigationStack {
        CartView(cart: cart)
    }
    .tabItem { Label("Cart", systemImage: "cart.circle") }
}
```

**이름만 바꿔도 동작한다.** `NavigationLink(destination:)` 방식은 [여전히 현행 API](./navigation-link-two-styles-mixed.md)이므로 함께 고칠 필요가 없다.

**주의할 차이가 하나 있다.** `NavigationView`는 iPad에서 자동으로 2컬럼(split) 레이아웃이 되지만 `NavigationStack`은 항상 스택이다. iPhone 전용 앱이라면 오히려 예측 가능해지는 것이고, iPad에서 split을 원한다면 `NavigationSplitView`를 써야 한다.

**`ZStack` + 투명 `NavigationLink` 패턴도 함께 정리할 수 있다.** 이건 `NavigationView` 시절의 우회책이었다. [히트 테스트 문서](./swiftui-hit-testing-vs-dom-events.md)에서 다룬 대로, 현행 API에서는 라벨에 직접 넣으면 된다.

```swift
List(Course.sample) { course in
    NavigationLink {
        CourseDetailView(course: course, cart: cart)
    } label: {
        CourseCardView(course: course)
    }
    .listRowSeparator(.hidden)
}
```

`ZStack`, `EmptyView()`, `.opacity(0)`이 모두 사라진다.

**더 나아가려면 값 기반으로 옮긴다.**

```swift
@State private var path: [Course] = []

NavigationStack(path: $path) {
    List(Course.sample) { course in
        NavigationLink(course.title, value: course)
    }
    .navigationDestination(for: Course.self) { course in
        CourseDetailView(course: course, cart: cart)
    }
}
```

이러면 `path`로 코드에서 화면을 제어할 수 있고, 목적지가 탭할 때 생성된다. 다만 `Course`가 `Hashable`을 채택해야 하고([enum과 Hashable](./enum-hashable-conformance.md) 참조), [`id`가 안정적이어야 한다](./duplicate-id-in-list.md)는 전제가 붙는다. 현재 `Course.sample`은 계산 프로퍼티라 그 전제가 깨져 있다.

**세 단계로 정리하면 이렇다.**

| 단계 | 작업 | 난이도 |
| --- | --- | --- |
| ① | `NavigationView` → `NavigationStack` | 이름만 교체 |
| ② | `ZStack` 패턴 → 라벨에 직접 | 코드가 줄어든다 |
| ③ | 값 기반 + `path` | `Hashable`·`id` 안정성 필요 |

①만 해도 deprecation 경고가 사라진다. ②는 가독성 개선이고, ③은 프로그래밍 방식 제어가 필요할 때 한다.

## 학습 체크리스트

- [ ] 주석 처리된 `NavigationView` 버전을 되살려 실행하고 deprecation 경고를 확인한다.
- [ ] `NavigationView`에 `.navigationViewStyle(.stack)`을 붙여 동작 차이를 본다.
- [ ] iPad 시뮬레이터에서 `NavigationView`가 컬럼으로 나뉘는 것을 확인한다.
- [ ] 같은 화면을 `NavigationSplitView`로 만들어 본다.
- [ ] `NavigationLink(destination:)` 방식과 `value:` 방식을 같은 목록에 각각 써 보고 비교한다.
- [ ] `navigationDestination`을 `List` **안**에 넣고 스크롤했을 때 문제가 생기는지 확인한다.
- [ ] `path` 배열에 값을 두 개 넣어 두고 앱 시작 시 이미 2단계 들어가 있는 것을 확인한다.
- [ ] `path.removeLast(2)`로 두 단계를 한 번에 빼 본다.
- [ ] `#available(iOS 16.0, *)` 분기를 작성해 본다.
- [ ] 프로젝트의 최소 배포 타겟을 iOS 15로 낮추고 어떤 에러가 나는지 본다.
- [ ] `navigationDestination`을 하나 지우고 해당 타입의 링크를 탭했을 때 어떻게 되는지 확인한다.
- [ ] `chapter-69`의 두 `NavigationView`를 `NavigationStack`으로 바꿔 경고가 사라지는지 확인한다.
- [ ] 바꾼 뒤 `NavigationLink(destination:)` 방식이 그대로 동작하는지 확인한다.
- [ ] iPad에서 `NavigationView`와 `NavigationStack`의 레이아웃 차이를 비교한다.
- [ ] `ZStack` + 투명 링크 패턴을 라벨 방식으로 정리해 코드 줄 수를 비교한다.

## 공식 참고 자료

- [Apple: NavigationStack](https://developer.apple.com/documentation/swiftui/navigationstack)
- [Apple: NavigationView (deprecated)](https://developer.apple.com/documentation/swiftui/navigationview)
- [Apple: NavigationSplitView](https://developer.apple.com/documentation/swiftui/navigationsplitview)
- [Apple: Migrating to new navigation types](https://developer.apple.com/documentation/swiftui/migrating-to-new-navigation-types)
- [Apple: NavigationLink](https://developer.apple.com/documentation/swiftui/navigationlink)
- [Apple: view.navigationDestination(for:destination:)](https://developer.apple.com/documentation/swiftui/view/navigationdestination(for:destination:))
- [Apple: NavigationPath](https://developer.apple.com/documentation/swiftui/navigationpath)
- [Apple: Navigation](https://developer.apple.com/documentation/swiftui/navigation)
- [Apple HIG: Navigation and search](https://developer.apple.com/design/human-interface-guidelines/navigation-and-search)
