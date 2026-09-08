# `NavigationLink` 두 방식의 공존 — 무엇을 쓰고, 섞으면 어떻게 되나

`value`와 `navigationDestination`이 연결되는 원리는 [별도 문서](./navigation-link-value-and-destination.md)에, deprecated된 이니셜라이저는 [여기](./deprecated-navigation-link-initializers.md)에 정리했다. 이 문서는 **두 현행 방식의 선택과 혼용**을 다룬다.

## 질문이 나온 코드

`chapter-59/chapter-59/ContentView.swift`

```swift
NavigationStack {
    VStack {
        Text("Dev Techie").font(.title)

        // ① 목적지를 직접 갖는 방식
        NavigationLink("first page") {
            Text("Hello View")
        }
        NavigationLink("second page") {
            Text("Next View")
        }

        // ② 값을 넘기는 방식
        NavigationLink(value: "New Page") {
            Text("third page")
        }
    }
    .navigationDestination(for: String.self) { value in
        Text("Third View")
    }
}
```

## 공부할 내용

### 먼저 짚을 것 — 두 방식 모두 현행이다

**"상충되는 두 방식"이 아니다.** Apple 문서가 `NavigationLink`의 이니셜라이저를 두 그룹으로 나눠 **둘 다 정식 API로** 제시한다.

```text
Presenting a destination view
  init(_:destination:)          iOS 13.0+   현행
  init(destination:label:)      iOS 13.0+   현행

Presenting a value
  init(_:value:)                iOS 16.0+   현행
  init(value:label:)            iOS 16.0+   현행

Deprecated symbols              ← 별도 섹션
  init(_:destination:isActive:)
  init(_:destination:tag:selection:)
```

**deprecated된 것은 `isActive:`와 `tag:selection:` 두 개뿐이다.** 목적지를 직접 갖는 방식은 여전히 유효하고 경고도 나오지 않는다. [chapter-58에서 본 경고](./deprecated-navigation-link-initializers.md)와 혼동하기 쉬운 지점이다.

### 어떤 것이 더 최신인가

**값 방식이 새롭다.** iOS 16에서 `NavigationStack`과 함께 도입됐다.

| | 목적지 직접 | 값 전달 |
| --- | --- | --- |
| 도입 | iOS 13.0 | **iOS 16.0** |
| 상태 | 현행 | 현행 |
| `navigationDestination` | 불필요 | **필요** |

다만 "새것이 항상 낫다"는 아니다. 각자 맞는 자리가 있다.

### 두 방식의 실질적 차이

**① 목적지가 만들어지는 시점**

이것이 가장 중요한 차이다.

```swift
// 목적지 직접 — 링크를 그릴 때 목적지도 만들어진다
NavigationLink("first page") {
    Text("Hello View")          // 이미 생성됨
}

// 값 전달 — 탭할 때 목적지가 만들어진다
NavigationLink(value: "New Page") { Text("third page") }
```

링크가 세 개면 차이가 안 느껴지지만, 목록이 100개면 목적지도 100개가 미리 만들어진다. 목적지가 무거운 뷰라면 체감된다.

**② `path`에 기록되는가**

```swift
@State private var path: [String] = []

NavigationStack(path: $path) {
    NavigationLink("A") { DetailA() }        // path에 안 남는다
    NavigationLink(value: "B") { Text("B") } // path에 "B"가 쌓인다
}
```

**목적지 직접 방식은 `path`를 거치지 않는다.** SwiftUI 내부 상태로만 관리된다. 그래서 `path.count`를 읽어도 그 화면은 세어지지 않고, `path = []`로 루트에 돌아가도 그 화면은 영향을 받지 않는다.

이것이 다음 절의 혼용 문제로 직결된다.

**③ 프로그래밍 방식 제어**

값 방식만 코드로 이동할 수 있다.

```swift
path.append("New Page")     // 링크를 탭한 것과 같은 효과
```

목적지 직접 방식은 이런 조작이 불가능하다. 딥링크나 상태 복원이 필요하면 값 방식이 필수다. [`NavigationPath`와 타입 배열](./navigation-path-and-typed-array.md) 참조.

### 어느 쪽이 더 많이 쓰이나

용도가 갈린다.

**목적지 직접 방식이 자연스러운 경우**

- 설정 화면처럼 **목적지가 고정된 소수의 링크**
- 목적지가 가볍고 개수가 적을 때
- 프로그래밍 제어가 필요 없을 때

```swift
List {
    NavigationLink("계정") { AccountSettings() }
    NavigationLink("알림") { NotificationSettings() }
    NavigationLink("정보") { AboutView() }
}
```

세 개뿐이고 각각 다른 화면이라 값 방식으로 만들면 오히려 번거롭다. `enum`을 정의하고 `navigationDestination`에서 `switch`를 써야 하니 코드가 늘어난다.

**값 방식이 필요한 경우**

- **데이터 목록**에서 상세로 가는 흐름
- 딥링크·푸시 알림 처리
- 상태 복원
- 여러 단계를 코드로 조작
- 목적지가 무겁거나 목록이 길 때

```swift
List(courses) { course in
    NavigationLink(course.title, value: course)
}
.navigationDestination(for: Course.self) { course in
    CourseDetail(course: course)
}
```

**실무 비중**은 대체로 이렇다. 데이터 기반 화면이 앱의 대부분을 차지하므로 값 방식이 주력이 되고, 설정처럼 고정된 메뉴에는 목적지 직접 방식이 남는다. 새 프로젝트라면 값 방식을 기본으로 두고, 정말 단순한 곳에만 클로저 방식을 쓰는 편이 일관성 유지에 좋다.

### 섞어 쓰면 문제가 없는가

**컴파일 에러나 런타임 크래시는 없다.** 두 방식이 서로 다른 경로로 동작하므로 충돌하지 않는다.

```text
NavigationLink("first page") { Text("Hello View") }
    → 자기 목적지를 직접 밀어 넣는다

NavigationLink(value: "New Page") { ... }
    → path에 "New Page" 추가
    → navigationDestination(for: String.self)가 잡아서 그린다
```

지금 코드는 정상 동작한다. 세 링크 모두 각자의 화면으로 간다.

**하지만 실제로 생길 수 있는 문제가 넷 있다.**

**① `path` 상태가 반쪽만 반영된다 — 가장 위험하다**

`path`를 쓰기 시작하면 문제가 드러난다.

```swift
@State private var path: [String] = []

NavigationStack(path: $path) {
    VStack {
        NavigationLink("first page") { Text("Hello View") }   // path에 안 남음
        NavigationLink(value: "New Page") { Text("third page") }
    }
    .navigationDestination(for: String.self) { _ in Text("Third View") }
}
```

"first page"로 들어간 상태에서 `path.count`는 **0**이다. 화면은 2단계인데 코드는 루트라고 인식한다. 이 불일치가 버그의 근원이 된다.

- "루트로 돌아가기" 버튼(`path = []`)이 일부 화면에서 동작하지 않는다
- 현재 깊이를 판단하는 로직이 틀린다
- 상태 복원 시 일부 화면이 복원되지 않는다
- 딥링크로 진입했을 때 스택 상태가 예상과 다르다

**지금 코드는 `path`를 쓰지 않으므로 이 문제가 드러나지 않는다.** 나중에 `NavigationStack(path:)`로 바꾸는 순간 나타난다.

**② `navigationDestination(for:)`이 광범위하게 잡는다**

```swift
.navigationDestination(for: String.self) { value in
    Text("Third View")
}
```

`String` **전체**를 처리하겠다는 선언이다. 지금은 값 링크가 하나뿐이지만, 나중에 다른 `String` 링크를 추가하면 **모두 이 목적지로 간다.**

```swift
NavigationLink(value: "New Page") { Text("third page") }
NavigationLink(value: "Settings") { Text("설정") }      // 이것도 "Third View"로 간다
```

`String`처럼 흔한 타입을 라우팅 키로 쓰면 이런 사고가 난다. `enum`으로 목적지를 명시하는 편이 안전하다.

```swift
enum Route: Hashable {
    case thirdPage
    case settings
}

.navigationDestination(for: Route.self) { route in
    switch route {
    case .thirdPage: Text("Third View")
    case .settings:  SettingsView()
    }
}
```

`switch`에서 case 누락을 컴파일러가 잡아 준다. [enum과 Hashable](./enum-hashable-conformance.md) 참조.

**③ 읽는 사람이 혼란스럽다**

같은 파일에서 세 링크가 두 가지 방식으로 쓰여 있으면, 새로 코드를 보는 사람은 "왜 다르게 썼지?"를 먼저 고민한다. 의도가 있어서 나눈 것인지 그냥 섞인 것인지 알 수 없다.

특히 값 방식 링크는 **목적지가 파일 다른 곳에 있어서** 어디로 가는지 즉시 보이지 않는다. `navigationDestination`을 찾아 올라가야 한다.

**④ 목적지가 미리 만들어진다**

목적지 직접 방식의 링크만큼 뷰가 미리 생성된다. 지금은 `Text` 두 개라 문제없지만, 무거운 뷰라면 비용이 된다.

### 그래서 이 코드는 어떻게 하는 게 좋은가

**목적이 학습이라면 지금 상태가 오히려 좋다.** 두 방식을 나란히 두고 차이를 관찰할 수 있다.

**일관성을 원한다면 한쪽으로 통일한다.**

목적지가 셋뿐이고 데이터 기반이 아니므로, **클로저 방식으로 통일**하는 것이 가장 단순하다.

```swift
NavigationStack {
    VStack {
        Text("Dev Techie").font(.title)
        NavigationLink("first page")  { Text("Hello View") }
        NavigationLink("second page") { Text("Next View") }
        NavigationLink("third page")  { Text("Third View") }
    }
}
```

`navigationDestination`이 필요 없어지고 코드가 짧아진다.

**프로그래밍 제어를 배우려면 값 방식으로 통일**한다.

```swift
enum Page: Hashable {
    case first, second, third
}

@State private var path: [Page] = []

NavigationStack(path: $path) {
    VStack {
        Text("Dev Techie").font(.title)
        NavigationLink("first page",  value: Page.first)
        NavigationLink("second page", value: Page.second)
        NavigationLink("third page",  value: Page.third)

        Button("바로 3번으로") { path = [.third] }
        Button("루트로") { path = [] }
    }
    .navigationDestination(for: Page.self) { page in
        switch page {
        case .first:  Text("Hello View")
        case .second: Text("Next View")
        case .third:  Text("Third View")
        }
    }
}
```

`path`로 할 수 있는 일이 드러나고, 모든 링크가 같은 경로를 쓴다.

### 지금 코드에서 눈여겨볼 두 가지

**① `value`를 쓰지 않는다**

```swift
NavigationLink(value: "New Page") { Text("third page") }
```
```swift
.navigationDestination(for: String.self) { value in
    Text("Third View")        // ← value("New Page")를 무시한다
}
```

`"New Page"`를 넘기지만 목적지에서 쓰지 않고 고정 문자열을 그린다. 값 방식의 장점(전달된 데이터로 화면 구성)이 사라진 상태다. 이러면 클로저 방식과 다를 바가 없다.

값을 활용하면 이렇게 된다.

```swift
.navigationDestination(for: String.self) { value in
    Text(value)               // "New Page"가 표시된다
}
```

**② 라벨과 값이 다르다**

```swift
NavigationLink(value: "New Page") {
    Text("third page")        // 화면에 보이는 것
}
```

목록에는 "third page"라고 표시되고, 전달되는 값은 `"New Page"`다. 의도한 것일 수 있지만 헷갈리기 쉽다. 라벨과 값의 관계는 [별도 문서](./navigation-link-value-and-destination.md)에서 다뤘다.

### 정리

```text
두 방식 모두 현행이다. deprecated는 isActive:와 tag:selection:뿐.

목적지 직접 (iOS 13+)
  쓸 곳: 설정 메뉴처럼 고정된 소수의 링크
  한계: path에 기록 안 됨, 코드 제어 불가, 목적지 미리 생성

값 전달 (iOS 16+)
  쓸 곳: 데이터 목록, 딥링크, 상태 복원
  필요: navigationDestination(for:) 등록

섞어 쓸 때의 위험
  ① path 상태가 반쪽만 반영 ← 가장 위험
  ② String 같은 흔한 타입을 키로 쓰면 광범위하게 잡힘
  ③ 읽는 사람의 혼란
  ④ 목적지 미리 생성

원칙: 한 스택 안에서는 한 방식으로. path를 쓸 계획이면 값 방식으로 통일.
```

## 학습 체크리스트

- [ ] 세 링크를 각각 탭해 모두 정상 동작하는지 확인한다 (충돌 없음).
- [ ] `NavigationStack(path: $path)`로 바꾸고 `path.count`를 화면에 표시한다.
- [ ] "first page"로 들어간 뒤 `path.count`가 0인 것을 확인한다.
- [ ] "third page"로 들어간 뒤 `path.count`가 1인 것을 확인한다.
- [ ] `path = []` 버튼을 만들어 어느 화면에서 동작하고 어느 화면에서 안 되는지 본다.
- [ ] `navigationDestination`의 `value`를 실제로 써서 `Text(value)`로 바꿔 본다.
- [ ] `NavigationLink(value: "Settings") { Text("설정") }`을 추가해 같은 목적지로 가는 것을 확인한다.
- [ ] `enum Page`를 만들어 값 방식으로 통일해 본다.
- [ ] 그 상태에서 `path = [.third]`로 바로 3번 화면에 진입해 본다.
- [ ] 클로저 방식으로 통일해 보고 코드 길이를 비교한다.
- [ ] 목적지에 `.onAppear { print("생성") }`을 넣어 두 방식의 생성 시점을 비교한다.
- [ ] `NavigationLink`의 라벨과 `value`를 다르게 두었을 때 무엇이 표시되는지 확인한다.
- [ ] `navigationDestination(for: String.self)`를 지우고 값 링크가 반응하지 않는 것을 확인한다.

## 공식 참고 자료

- [Apple: NavigationLink](https://developer.apple.com/documentation/swiftui/navigationlink)
- [Apple: NavigationLink.init(destination:label:)](https://developer.apple.com/documentation/swiftui/navigationlink/init(destination:label:))
- [Apple: NavigationLink.init(value:label:)](https://developer.apple.com/documentation/swiftui/navigationlink/init(value:label:))
- [Apple: NavigationLink.init(_:value:)](https://developer.apple.com/documentation/swiftui/navigationlink/init(_:value:))
- [Apple: NavigationLink deprecated symbols](https://developer.apple.com/documentation/swiftui/navigationlink-deprecated)
- [Apple: view.navigationDestination(for:destination:)](https://developer.apple.com/documentation/swiftui/view/navigationdestination(for:destination:))
- [Apple: NavigationStack](https://developer.apple.com/documentation/swiftui/navigationstack)
- [Apple: NavigationPath](https://developer.apple.com/documentation/swiftui/navigationpath)
- [Apple: Migrating to new navigation types](https://developer.apple.com/documentation/swiftui/migrating-to-new-navigation-types)
- [Apple: Navigation](https://developer.apple.com/documentation/swiftui/navigation)
