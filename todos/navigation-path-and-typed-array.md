# `NavigationPath`와 타입 배열 — 무엇이 다르고 언제 쓰는가

`NavigationStack`이 `NavigationView`를 어떻게 대체했는지는 [별도 문서](./navigation-stack-vs-navigation-view.md)에 정리했다. 이 문서는 **`path`를 무엇으로 관리할 것인가**를 다룬다.

## 질문이 나온 코드

`chapter-57/chapter-57/ContentView.swift`에 두 방식이 나란히 있다.

```swift
struct ContentView: View {
    @State private var path: [DevTechieCourse] = [
        DevTechieCourse.exampleData[0],
        DevTechieCourse.exampleData[1],
    ]
    // ...
}
```

```swift
struct NavigationStateExample: View {
    @State private var path = NavigationPath()
    // ...
    Button("Pop to root") {
        path = NavigationPath()
    }
}
```

## 1부 — `NavigationPath`는 무엇인가

### 질문 확인: "모든 View의 변경 히스토리를 저장하는 객체인가?"

**절반은 맞고 절반은 다르다.** 정확히 하면 이렇다.

- **"히스토리"가 아니라 "현재 쌓여 있는 화면들"** 이다. 뒤로 간 화면은 기록으로 남지 않고 **사라진다.**
- **"View"를 저장하는 것이 아니라 "값"을 저장**한다. 뷰 자체는 들어 있지 않다.

Apple의 설명이 정확하다.

> You can manage the state of a `NavigationStack` by initializing the stack with a binding to a collection of data. **The stack stores data items in the collection for each view on the stack.** You also can read and write the collection to observe and alter the stack's state.

**스택에 올라간 화면 하나당 값 하나**가 대응된다. 브라우저의 방문 기록(뒤로 간 것도 남음)이 아니라 **함수 호출 스택**에 가깝다.

```text
path = []                        →  루트 화면만
path = [A]                       →  루트 → A
path = [A, B]                    →  루트 → A → B
뒤로 가기                         →  path = [A]   ← B는 사라진다
```

### 질문 확인: "새 객체로 바꾸면 최초 화면으로 가는가?"

**맞다.** 그 이유가 위 구조에서 나온다.

```swift
path = NavigationPath()      // 빈 path
```

빈 `NavigationPath`는 "쌓인 화면이 없다"는 뜻이므로 루트만 남는다. 예제의 "Pop to root" 버튼이 이 원리를 쓴다.

배열 방식도 똑같다.

```swift
path = []                    // 동일하게 루트로
```

특정 단계까지만 빼고 싶으면 이렇게 한다.

```swift
path.removeLast()            // 한 단계 뒤로
path.removeLast(2)           // 두 단계 뒤로
```

### `NavigationPath`의 핵심 성질 — 타입 소거

이것이 배열과의 근본적 차이다.

> When a stack displays views that rely on **only one kind of data**, you can use a standard collection, like an array, to hold the data. If you need to present **different kinds of data** in a single stack, use a navigation path instead. **The path uses type erasure so you can manage a collection of heterogeneous elements.**

`NavigationPath`는 서로 다른 타입을 한 컨테이너에 담을 수 있다. 예제의 `NavigationStateExample`이 정확히 그 상황이다.

```swift
NavigationLink(value: "Mastering iOS and UIKit")   // String
NavigationLink("Mastering SwiftUI", value: Color.orange)  // Color
```

```swift
.navigationDestination(for: String.self) { ... }
.navigationDestination(for: Color.self) { ... }
```

`String`과 `Color`가 섞여 쌓인다. `[String]` 배열로는 담을 수 없다.

### API 목록

`NavigationPath`가 제공하는 것은 단순하다.

| 멤버 | 용도 |
| --- | --- |
| `init()` | 빈 path |
| `init(_:)` | 시퀀스나 `CodableRepresentation`으로 생성 |
| `isEmpty` | 비어 있는지 |
| `count` | 쌓인 화면 수 |
| `append(_:)` | 화면 추가 |
| `removeLast(_:)` | 뒤로 가기 |
| `codable` | 직렬화용 표현 |

`append`의 시그니처에 제약이 드러난다.

```swift
mutating func append<V>(_ value: V) where V : Decodable, V : Encodable, V : Hashable
```

`Hashable`뿐 아니라 **`Codable`도 요구한다.** 상태 저장·복원을 위해서다. [enum과 Hashable 문서](./enum-hashable-conformance.md)에서 다룬 자동 합성 덕분에 단순한 타입은 그냥 통과한다.

**주의**: `NavigationPath`는 `Collection`이 아니다. 순회하거나 인덱스로 접근할 수 없다. 넣고, 빼고, 개수를 세는 것만 된다. 안에 든 값을 **읽을 수 없다**는 점이 배열과 크게 다르다.

### 상태 저장·복원

`NavigationPath`만의 기능이다.

> When the values you present on the navigation stack conform to the `Codable` protocol, you can use the path's `codable` property to get a serializable representation of the path. Use that representation to save and restore the contents of the stack.

```swift
class MyModelObject: ObservableObject {
    @Published var path: NavigationPath

    init() {
        if let data = Self.readSerializedData() {
            do {
                let representation = try JSONDecoder().decode(
                    NavigationPath.CodableRepresentation.self,
                    from: data)
                self.path = NavigationPath(representation)
            } catch {
                self.path = NavigationPath()
            }
        } else {
            self.path = NavigationPath()
        }
    }

    func save() {
        guard let representation = path.codable else { return }
        // ... 인코딩해서 저장
    }
}
```

앱이 백그라운드로 갈 때 저장하는 패턴도 문서에 나온다.

```swift
.onChange(of: scenePhase) { phase in
    if phase == .background {
        pathState.save()
    }
}
```

[`\.scenePhase`](./environment-property-wrapper.md)와 [`onChange`](./onchange-old-new-value.md)의 조합이다.

배열도 `Codable`이면 직접 저장할 수 있지만, `NavigationPath`는 **타입 정보까지 함께 직렬화**해 준다는 점이 다르다.

## 2부 — 두 방식 비교

### 한눈에

| | `[DevTechieCourse]` (타입 배열) | `NavigationPath` |
| --- | --- | --- |
| 담을 수 있는 타입 | **한 가지** | **여러 가지** (타입 소거) |
| 값 읽기 | **가능** — `path[0]`, `for`, `map` | **불가능** |
| 개수 세기 | 가능 | 가능 (`count`) |
| 타입 안전성 | **컴파일 타임 보장** | 런타임에 매칭 |
| 상태 저장 | 직접 구현 | `codable` 제공 |
| 요구 프로토콜 | `Hashable` | `Hashable` + `Codable` |
| 디버깅 | `print(path)`로 내용 확인 | 내용 확인 어려움 |
| 코드 가독성 | 명확 | 추상적 |

### 언제 타입 배열을 쓰나

**한 종류의 데이터만 쌓는 화면**이라면 배열이 낫다. 예제의 `ContentView`가 그 경우다.

```swift
@State private var path: [DevTechieCourse] = []
```

**장점이 실질적이다.**

**① 안에 든 값을 읽을 수 있다.** 이게 가장 크다.

```swift
if path.contains(where: { $0.title.hasPrefix("Mastering") }) { ... }
let current = path.last
Text("현재 깊이: \(path.count), 최상단: \(path.last?.title ?? "루트")")
```

`NavigationPath`로는 불가능하다.

**② 컴파일러가 타입을 검증한다.** 잘못된 타입을 넣으면 컴파일 에러다.

**③ 배열의 모든 기능을 쓴다.** `map`, `filter`, `first(where:)`, 인덱스 접근.

**④ 디버깅이 쉽다.** `print(path)` 한 줄로 현재 상태가 보인다.

**⑤ `Codable`이 필수가 아니다.** `Hashable`만 있으면 된다.

예제가 초기값을 넣어 둔 것도 배열이라 자연스럽다.

```swift
@State private var path: [DevTechieCourse] = [
    DevTechieCourse.exampleData[0],
    DevTechieCourse.exampleData[1],
]
```

앱을 켜면 이미 2단계 들어가 있는 상태로 시작한다. 딥링크나 상태 복원을 흉내 내는 코드다.

### 언제 `NavigationPath`를 쓰나

**여러 타입이 섞이는 화면**이다. 이 조건이 아니면 쓸 이유가 거의 없다.

```swift
NavigationLink(value: someString)
NavigationLink(value: someColor)
NavigationLink(value: someProduct)
```

한 스택에서 이렇게 다양한 타입으로 이동한다면 배열로는 불가능하다.

**두 번째 이유는 상태 복원**이다. `codable` 프로퍼티가 타입 정보까지 직렬화해 주므로, 여러 타입이 섞여도 복원이 된다.

### 그래서 어느 쪽을 추천하나

**기본은 타입 배열이다.** 이유는 단순하다.

- 대부분의 화면은 **한 종류의 데이터**로 이동한다
- 값을 읽을 수 있다는 점이 실무에서 계속 필요해진다
- 타입 안전성이 높고 디버깅이 쉽다

**`NavigationPath`는 필요할 때 꺼내 쓴다.** 여러 타입이 섞이거나 상태 복원이 필요할 때다.

Apple의 안내도 같은 방향이다.

> When a stack displays views that rely on only one kind of data, **you can use a standard collection, like an array**, to hold the data. **If you need to present different kinds of data in a single stack, use a navigation path instead.**

"한 종류면 배열, 여러 종류면 path" — 기준이 명확하다.

### 중간 지대 — `enum`으로 통합하기

여러 화면이 있지만 타입 안전성도 지키고 싶다면 `enum`이 좋은 선택이다.

```swift
enum Route: Hashable {
    case course(DevTechieCourse)
    case category(String)
    case color(Color)
}

@State private var path: [Route] = []
```

```swift
.navigationDestination(for: Route.self) { route in
    switch route {
    case .course(let c):   CourseDetail(course: c)
    case .category(let s): CategoryView(name: s)
    case .color(let c):    ColorView(color: c)
    }
}
```

**이 방식의 장점이 크다.**

- 여러 종류를 담으면서도 **배열의 이점을 전부 유지**한다
- `navigationDestination`이 **하나로 통합**된다
- `switch`에서 case 누락을 컴파일러가 잡는다
- 라우트 전체가 한곳에 정의되어 앱 구조가 드러난다

[chapter-51의 딥링크 예제](./deep-link-and-url-scheme.md)가 이 패턴이었다.

```swift
enum Route: Hashable {
    case test
    case support
}

func handleDeepLinkURL(_ url: URL) {
    switch url.host {
    case "test":    path.append(Route.test)
    case "support": path.append(Route.support)
    default:        break
    }
}
```

다만 거기서는 `NavigationPath`를 썼는데, `[Route]` 배열로 바꾸면 현재 위치를 읽을 수 있어 더 유리하다.

### 선택 기준 정리

```text
path에 무엇을 쌓는가?
│
├─ 한 종류의 타입만
│    └─ [Model] 배열                     ← 기본 선택
│
├─ 여러 종류지만 내가 정의할 수 있다
│    └─ enum Route + [Route] 배열         ← 대부분 이게 최선
│
└─ 여러 종류이고 통합할 수 없다
     (외부 타입, 동적 타입 등)
     └─ NavigationPath
          └─ 상태 복원이 필요하면 codable 활용
```

### 이 예제에서 확인할 것

두 구조체가 각 방식을 하나씩 보여 준다.

**`ContentView` — 타입 배열**

```swift
@State private var path: [DevTechieCourse] = [...]
```

`DevTechieCourse` 하나만 쌓으므로 배열이 적절하다.

**`NavigationStateExample` — `NavigationPath`**

```swift
@State private var path = NavigationPath()
NavigationLink(value: "Mastering iOS and UIKit")          // String
NavigationLink("Mastering SwiftUI", value: Color.orange)  // Color
```

`String`과 `Color`가 섞이므로 `NavigationPath`가 필요하다. **이 예제는 `NavigationPath`를 쓸 정당한 이유가 있는 경우다.**

"Pop to root" 버튼도 눈여겨볼 만하다.

```swift
Button("Pop to root") {
    path = NavigationPath()
}
```

`removeLast(path.count)` 대신 새 인스턴스로 교체하는 방식이다. 더 간결하고 의도가 분명하다.

## 학습 체크리스트

- [ ] `ContentView`의 초기 `path`에 값 두 개를 넣고 앱이 2단계 들어간 상태로 시작하는지 확인한다.
- [ ] `path.count`를 화면에 표시해 이동할 때마다 변하는 것을 본다.
- [ ] 배열 `path`에서 `path.last?.title`을 읽어 현재 화면을 표시해 본다.
- [ ] `NavigationPath`에서 같은 것을 시도해 값을 읽을 수 없음을 확인한다.
- [ ] `path.removeLast()`와 `path.removeLast(2)`의 차이를 확인한다.
- [ ] `path = []`와 `path = NavigationPath()`가 같은 효과인지 비교한다.
- [ ] 배열 `path`에 다른 타입을 넣으려 시도해 컴파일 에러를 확인한다.
- [ ] `NavigationPath`에 `String`과 `Color`를 섞어 넣고 정상 동작하는지 본다.
- [ ] `NavigationPath`가 `Collection`이 아니라 순회할 수 없음을 확인한다.
- [ ] `enum Route`를 만들어 `[Route]` 배열 방식으로 바꿔 본다.
- [ ] 그 상태에서 `navigationDestination`이 하나로 통합되는지 확인한다.
- [ ] `Codable`이 아닌 타입을 `NavigationPath.append`에 넣어 에러를 확인한다.
- [ ] `path.codable`로 직렬화해 `print`로 내용을 본다.
- [ ] `scenePhase`가 `.background`일 때 path를 저장하는 코드를 작성한다.

## 공식 참고 자료

- [Apple: NavigationPath](https://developer.apple.com/documentation/swiftui/navigationpath)
- [Apple: NavigationPath.append(_:)](https://developer.apple.com/documentation/swiftui/navigationpath/append(_:))
- [Apple: NavigationPath.removeLast(_:)](https://developer.apple.com/documentation/swiftui/navigationpath/removelast(_:))
- [Apple: NavigationPath.codable](https://developer.apple.com/documentation/swiftui/navigationpath/codable)
- [Apple: NavigationPath.CodableRepresentation](https://developer.apple.com/documentation/swiftui/navigationpath/codablerepresentation)
- [Apple: NavigationStack](https://developer.apple.com/documentation/swiftui/navigationstack)
- [Apple: NavigationStack.init(path:root:)](https://developer.apple.com/documentation/swiftui/navigationstack/init(path:root:))
- [Apple: view.navigationDestination(for:destination:)](https://developer.apple.com/documentation/swiftui/view/navigationdestination(for:destination:))
- [Apple: Navigation](https://developer.apple.com/documentation/swiftui/navigation)
