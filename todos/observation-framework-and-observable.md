# `Observation` 모듈과 `@Observable` 매크로

## 질문이 나온 코드

`chapter-51/chapter-51/ContentView.swift`

```swift
import Observation
import SwiftUI
```

```swift
@Observable
final class NavigationCoordinator {
    var path = NavigationPath()

    func handleDeepLinkURL(_ url: URL) { /* ... */ }
}
```

```swift
struct ContentView: View {
    @State private var coordinator = NavigationCoordinator()

    var body: some View {
        NavigationStack(path: $coordinator.path) { /* ... */ }
    }
}
```

## 1부 — `Observation` 모듈은 무엇인가

### 관찰자 패턴을 언어 차원에서 구현한 프레임워크다

> Observation provides a robust, type-safe, and performant implementation of the observer design pattern in Swift. This pattern allows an observable object to maintain a list of observers and notify them of specific or general state changes. This has the advantages of not directly coupling objects together and allowing implicit distribution of updates across potential multiple observers.

세 가지 일을 한다.

> The Observation frameworks provides the following capabilities:
> - Marking a type as observable
> - Tracking changes within an instance of an observable type
> - Observing and utilizing those changes elsewhere, such as in an app's user interface

**SwiftUI 전용이 아니라는 점**이 중요하다. Swift 표준 라이브러리 쪽 프레임워크이고, SwiftUI가 이를 채택해 쓰는 구조다. 서버 사이드 Swift나 UIKit에서도 쓸 수 있다.

### 모듈에 들어 있는 것들

| 종류 | 이름 | 역할 |
| --- | --- | --- |
| 매크로 | `@Observable` | 타입을 관찰 가능하게 만듦 |
| 매크로 | `@ObservationIgnored` | 특정 프로퍼티를 추적에서 제외 |
| 매크로 | `@ObservationTracked` | 개별 프로퍼티 추적 (보통 직접 안 씀) |
| 프로토콜 | `Observable` | 관찰 가능함을 나타내는 표식 |
| 함수 | `withObservationTracking(_:onChange:)` | 변경 추적 |
| 타입 | `ObservationRegistrar` | 관찰자 등록·통지 관리 (매크로가 생성) |
| 타입 | `ObservationTracking` | 추적 상태 |

`withObservationTracking`이 SwiftUI 없이 관찰을 쓰는 방법이다.

```swift
func render() {
    withObservationTracking {
        for car in cars {
            print(car.name)
        }
    } onChange: {
        print("Schedule renderer.")
    }
}
```

Apple의 설명이 동작 원리를 정확히 말한다.

> the function calls the onChange closure when a car's name changes. However, it doesn't call the closure when a car's needsRepair flag changes. That's because the function only tracks properties read in its apply closure, and the closure doesn't read the needsRepair property.

**읽은 프로퍼티만 추적한다.** 이 성질이 2부에서 다룰 SwiftUI 최적화의 핵심이 된다.

### `import Observation`이 꼭 필요한가

이 예제에서는 **사실 없어도 된다.** SwiftUI가 `Observation`을 재수출(re-export)하기 때문에 `import SwiftUI`만 있어도 `@Observable`을 쓸 수 있다.

명시적으로 쓰는 것이 나쁘지는 않다. 의존성이 드러나고, 나중에 `withObservationTracking` 같은 모듈 고유 API를 쓰게 되면 필요해진다. 다만 "없으면 컴파일이 안 된다"고 오해하지 않는 것이 좋다.

## 2부 — `@Observable` 매크로

### 무엇을 하는가

> To declare a type as observable, attach the `@Observable` macro to the type declaration. This macro declares and implements conformance to the `Observable` protocol to the type at compile time.

컴파일 시점에 코드를 생성해 준다. 매크로 선언을 보면 무엇이 생기는지 보인다.

```swift
@attached(member, names: named(_$observationRegistrar), named(access),
          named(withMutation), named(shouldNotifyObservers))
@attached(memberAttribute)
@attached(extension, conformances: Observable)
macro Observable()
```

- `ObservationRegistrar` 인스턴스를 프로퍼티로 추가한다
- 각 저장 프로퍼티를 접근 추적이 되는 형태로 바꾼다
- `Observable` 프로토콜 준수를 붙인다

그래서 `NavigationCoordinator`는 이렇게만 쓰면 된다.

```swift
@Observable
final class NavigationCoordinator {
    var path = NavigationPath()   // 별도 표시 없이 자동으로 추적됨
}
```

`@Published` 같은 표시가 필요 없다는 점이 이전 방식과의 큰 차이다.

**중요한 주의사항**이 하나 있다.

> The `Observable` macro, in addition to adding observation functionality, also conforms your data model type to the `Observable` protocol, which serves as a signal to other APIs that your type supports observation. Don't apply the Observable protocol by itself to your data model type, since that alone doesn't add any observation functionality. Instead, always use the Observable macro when adding observation support to your type.

```swift
@Observable class Model { }        // ✅
class Model: Observable { }        // ⚠️ 프로토콜만 붙이면 아무 기능도 없다
```

### 왜 쓰는가 — 뷰가 읽은 프로퍼티만 갱신된다

가장 큰 이점이다.

> In SwiftUI, a view forms a dependency on an observable data model object, such as an instance of `Book`, when the view's `body` property reads a property of the object. If body doesn't read any properties of an observable data model object, the view doesn't track any dependencies.
>
> When a tracked property changes, SwiftUI updates the view. If other properties change that `body` doesn't read, the view is unaffected and avoids unnecessary updates.

```swift
@Observable class Book: Identifiable {
    var title = "Sample Book Title"
    var author = Author()
    var isAvailable = true
}

struct BookView: View {
    var book: Book
    var body: some View {
        Text(book.title)      // title만 읽는다
    }
}
```

이 뷰는 `title`이 바뀔 때만 갱신되고 `author`나 `isAvailable`이 바뀌어도 무관하다. 구형 `ObservableObject`는 `objectWillChange`가 한 번 발화하면 **구독한 모든 뷰가 갱신**됐다. 이 차이가 성능으로 직결된다.

**계산 프로퍼티도 추적된다.**

```swift
@Observable class Library {
    var books: [Book] = [Book(), Book(), Book()]

    var availableBooksCount: Int {
        books.filter(\.isAvailable).count
    }
}
```

`availableBooksCount`를 읽는 뷰는 그 값이 실제로 달라질 때 갱신된다.

**컬렉션 자체의 변화도 잡는다.**

> When a view forms a dependency on a collection of objects, of any collection type, the view tracks changes made to the collection itself. (…) As changes occur to `books`, such as inserting, deleting, moving, or replacing items in the collection, SwiftUI updates the view.

예제의 `coordinator.path`가 여기 해당한다. `NavigationPath`에 값을 `append`하면 그 변화가 감지되어 화면이 전환된다.

### 이 예제에서의 흐름

```text
① 딥링크 URL 수신
   .onOpenURL { url in coordinator.handleDeepLinkURL(url) }
        ↓
② coordinator.path.append(Route.test)
        ↓
③ @Observable이 path 변경을 통지
        ↓
④ NavigationStack(path: $coordinator.path)가 갱신
        ↓
⑤ navigationDestination이 TestView를 표시
```

`@Observable`이 없으면 ③이 일어나지 않아 화면이 바뀌지 않는다.

### 언제 쓰는가

**써야 할 때**

- **여러 뷰가 공유하는 상태**를 담을 때 — 이 예제의 네비게이션 좌표계처럼
- 뷰 계층 깊은 곳까지 전달해야 하는 모델
- 메서드와 로직을 함께 담아야 할 때 (`@State`의 값 타입으로는 한계가 있다)
- 참조 의미론이 필요할 때 — 여러 곳에서 같은 인스턴스를 봐야 할 때

**안 써도 될 때**

- 뷰 하나가 소유하는 단순한 값 → `@State`로 충분하다
- 부모가 소유한 값을 자식이 고칠 때 → `@Binding`
- 값 타입으로 충분한 데이터 → `struct`

### 다른 래퍼와 어떻게 조합하나

`@Observable` 객체를 뷰에서 잡는 방법이 상황별로 다르다.

| 상황 | 방법 |
| --- | --- |
| 이 뷰가 객체를 **소유**한다 | `@State private var model = Model()` |
| 부모에게서 **전달**받는다 | `var model: Model` (래퍼 없이) |
| **환경**에서 꺼낸다 | `@Environment(Model.self) private var model` |

예제가 첫 번째다.

```swift
@State private var coordinator = NavigationCoordinator()
```

`@Observable` 클래스인데 `@State`를 쓰는 것이 처음엔 어색해 보인다. 여기서 `@State`는 **값 변화를 감지하는 역할이 아니라 인스턴스의 수명을 뷰에 묶는 역할**이다. 뷰가 다시 그려질 때마다 새 `NavigationCoordinator`가 만들어지지 않게 해 준다. 변화 감지는 `@Observable`이 담당한다.

두 번째 경우, 즉 그냥 프로퍼티로 받을 때도 관찰이 동작한다는 점이 중요하다. 구형 방식에서는 `@ObservedObject`가 필요했다.

환경 주입은 [`@Environment` 문서](./environment-property-wrapper.md)에 정리했다.

### 추적에서 제외하기 — `@ObservationIgnored`

모든 프로퍼티를 추적할 필요는 없다.

```swift
@Observable
final class NavigationCoordinator {
    var path = NavigationPath()

    @ObservationIgnored
    private var analyticsBuffer: [String] = []   // UI와 무관 → 추적 불필요
}
```

캐시, 로그 버퍼처럼 화면과 무관한 것에 붙이면 불필요한 갱신을 막는다.

### 구형 `ObservableObject`와 비교

| | `ObservableObject` (구형) | `@Observable` (현행) |
| --- | --- | --- |
| 프로퍼티 표시 | `@Published` 필요 | **불필요** |
| 뷰에서 잡기 | `@ObservedObject`, `@StateObject`, `@EnvironmentObject` | `@State`, 일반 프로퍼티, `@Environment` |
| 갱신 범위 | 객체 변경 시 **구독한 뷰 전부** | **읽은 프로퍼티에 의존한 뷰만** |
| 계산 프로퍼티 | 추적 안 됨 | 추적됨 |
| 옵셔널·컬렉션 | 다루기 번거로움 | 자연스러움 |
| 최소 버전 | iOS 13 | **iOS 17** |

`@Observable`은 iOS 17부터다. 그 이하를 지원해야 하면 여전히 `ObservableObject`를 써야 한다.

Apple도 마이그레이션을 권한다. `EnvironmentObject`에 대한 안내가 그 예다.

> If your observable object conforms to the `Observable` protocol, use `Environment` instead of `EnvironmentObject`.

### 주의점

- **`class`에만 붙는다.** `struct`에는 쓸 수 없다. 참조 타입이어야 여러 곳에서 같은 인스턴스를 관찰할 수 있다.
- **`final`을 붙이는 것이 좋다.** 예제도 `final class`다. 상속 계획이 없으면 최적화에 유리하다.
- **`@State`로 잡을 때 초기화는 한 번만 일어난다.** 뷰가 다시 만들어져도 인스턴스는 유지된다.
- **메인 스레드에서 갱신한다.** UI를 건드리는 변경은 main actor에서.
- **매크로가 생성한 코드를 볼 수 있다.** Xcode에서 `@Observable`을 우클릭 → Expand Macro로 확인하면 이해가 빨라진다.

## 학습 체크리스트

- [ ] `import Observation`을 지우고도 컴파일되는지 확인한다.
- [ ] `@Observable`을 우클릭해 Expand Macro로 생성된 코드를 본다.
- [ ] `@Observable`을 지우고 딥링크로 화면 전환이 안 되는 것을 확인한다.
- [ ] `class Model: Observable { }`처럼 프로토콜만 붙여 보고 동작하지 않음을 확인한다.
- [ ] 프로퍼티 두 개를 가진 `@Observable` 클래스를 만들고, 하나만 읽는 뷰가 다른 쪽 변경에 반응하지 않는 것을 확인한다.
- [ ] 같은 실험을 `ObservableObject` + `@Published`로 해서 뷰 전체가 갱신되는 것과 비교한다.
- [ ] 계산 프로퍼티를 추가하고 그 값이 추적되는지 확인한다.
- [ ] `@ObservationIgnored`를 붙인 프로퍼티가 갱신을 유발하지 않는 것을 확인한다.
- [ ] `@State`를 떼고 `var coordinator = NavigationCoordinator()`로 바꿔 뷰 갱신마다 새 인스턴스가 생기는지 관찰한다.
- [ ] `coordinator`를 자식 뷰에 그냥 프로퍼티로 넘겨도 관찰이 되는지 확인한다.
- [ ] `withObservationTracking`으로 SwiftUI 없이 변경을 감지해 본다.
- [ ] `@Observable`을 `struct`에 붙여 보고 에러를 확인한다.
- [ ] `.environment(coordinator)`로 주입하고 자손에서 `@Environment(NavigationCoordinator.self)`로 꺼내 본다.

## 공식 참고 자료

- [Apple: Observation](https://developer.apple.com/documentation/observation)
- [Apple: Observable() 매크로](https://developer.apple.com/documentation/observation/observable())
- [Apple: Observable 프로토콜](https://developer.apple.com/documentation/observation/observable)
- [Apple: ObservationIgnored()](https://developer.apple.com/documentation/observation/observationignored())
- [Apple: withObservationTracking(_:onChange:)](https://developer.apple.com/documentation/observation/withobservationtracking(_:onchange:))
- [Apple: ObservationRegistrar](https://developer.apple.com/documentation/observation/observationregistrar)
- [Apple: Managing model data in your app](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app)
- [Apple: Migrating from the Observable Object protocol to the Observable macro](https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro)
- [Apple: State](https://developer.apple.com/documentation/swiftui/state)
- [Apple: Environment](https://developer.apple.com/documentation/swiftui/environment)
