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

### 마이그레이션 절차 — `chapter-69`의 `Cart`를 예로

Apple이 마이그레이션 전용 문서를 제공한다. 얻는 이점을 이렇게 정리한다.

> Adopting Observation provides your app with the following benefits:
> - Tracking optionals and collections of objects, which isn't possible when using `ObservableObject`.
> - Using existing data flow primitives like `State` and `Environment` instead of object-based equivalents such as `StateObject` and `EnvironmentObject`.
> - Updating views based on changes to the observable properties that a view's `body` reads instead of any property changes that occur to an observable object, **which can help improve your app's performance**.

`chapter-69/chapter-69/Cart.swift`가 구형 방식이다.

```swift
import SwiftUI
import Foundation
internal import Combine

class Cart: ObservableObject {
    @Published var courses: [Course] = []

    func addCourse(course: Course) { courses.append(course) }
    func deleteCourse(idSet: IndexSet) { courses.remove(atOffsets: idSet) }
}
```

**단계별로 옮기면 이렇게 된다.**

**① 모델 — `ObservableObject`를 `@Observable`로**

> To adopt Observation in an existing app, begin by replacing `ObservableObject` in your data model type with the `Observable` macro. (…) Then **remove the `Published` property wrapper** from observable properties. Observation doesn't require a property wrapper to make a property observable.

```swift
import Foundation
// Combine import가 불필요해진다

@Observable
final class Cart {
    var courses: [Course] = []       // @Published 제거

    func addCourse(course: Course) { courses.append(course) }
    func deleteCourse(idSet: IndexSet) { courses.remove(atOffsets: idSet) }
}
```

**`internal import Combine`이 사라지는 것도 이점**이다. `ObservableObject`와 `@Published`가 Combine 소속이라 필요했던 import다. [Combine 문서](./combine.md) 참조.

추적하고 싶지 않은 프로퍼티가 있으면 `@ObservationIgnored`를 붙인다.

> If you have properties that are accessible to an observer that you don't want to track, apply the `ObservationIgnored` macro to the property.

**② 소유하는 뷰 — `@StateObject`를 `@State`로**

```swift
// BEFORE
@StateObject private var library = Library()
// AFTER
@State private var library = Library()
```

**③ 전달받는 뷰 — `@ObservedObject`를 제거**

`chapter-69/chapter-69/CartView.swift`가 여기 해당한다.

```swift
// BEFORE
@ObservedObject var cart: Cart

// AFTER
var cart: Cart              // 래퍼가 필요 없다
```

> Next, remove the `ObservedObject` property wrapper from the book variable in the `BookView`. This property wrapper isn't needed when adopting Observation. **That's because SwiftUI automatically tracks any observable properties that a view's `body` reads directly.**

**④ 환경 주입 — `environmentObject`를 `environment`로**

```swift
// BEFORE
LibraryView().environmentObject(library)
struct LibraryView: View { @EnvironmentObject var library: Library }

// AFTER
LibraryView().environment(library)
struct LibraryView: View { @Environment(Library.self) var library }
```

**⑤ 바인딩이 필요하면 `@Bindable`**

> However, if a view needs a binding to an observable type, replace `ObservedObject` with the `Bindable` property wrapper.

```swift
@Bindable var book: Book
TextField("Title", text: $book.title)
```

`@Observable` 객체의 프로퍼티에 `$`로 바인딩을 만들려면 `@Bindable`이 필요하다. [프로퍼티 래퍼의 `$`](./property-wrapper-dollar-sign.md) 참조.

**점진적으로 옮겨도 된다**

> You don't need to make a wholesale replacement of the `ObservableObject` protocol throughout your app. Instead, you can make changes incrementally. Start by changing one data model type to use the `Observable` macro. **Your app can mix data model types that use different observation systems.**

`@StateObject`와 `@ObservedObject`도 `@Observable` 타입을 받아 준다. 모델만 먼저 바꾸고 뷰는 나중에 정리해도 동작한다.

**동작 차이를 알아 둘 것**

> You may notice slight behavioral differences in your app based on the tracking method. For instance, when tracking as `Observable`, SwiftUI updates a view only when an observable property changes **and the view's `body` reads the property directly**. The view doesn't update when observable properties not read by body changes. In contrast, a view updates when **any** published property of an `ObservableObject` instance changes, even if the view doesn't read the property that changes.

이것이 성능 이점의 근원이자, 동작이 미묘하게 달라지는 지점이다.

### `chapter-69`에서 함께 고칠 것 — 실제 버그

마이그레이션과 별개로 **`CourseHome`에 문제가 있다.**

```swift
struct CourseHome: View {
    var cart: Cart = Cart()          // ⚠️ 래퍼가 없다
```

`CourseHome`은 `struct`이고, SwiftUI는 뷰를 자주 다시 만든다. **`@StateObject`(구형) 또는 `@State`(현행)가 없으면 뷰가 재생성될 때마다 `Cart()`가 새로 만들어질 수 있다.** 장바구니에 담은 항목이 사라질 수 있다는 뜻이다.

`@State`의 역할이 여기서 드러난다. [Observation 문서 앞부분](#다른-래퍼와-어떻게-조합하나)에서 다룬 대로, `@Observable` 객체에 `@State`를 붙이는 것은 **값 변화 감지가 아니라 인스턴스 수명을 뷰에 묶는 역할**이다.

```swift
struct CourseHome: View {
    @State private var cart = Cart()      // 수명이 뷰에 묶인다
```

**하위 뷰로 전달하는 방식도 두 가지가 있다.**

```swift
// ① 프로퍼티로 직접 전달 — 현재 방식
CartView(cart: cart)

// ② 환경으로 주입 — 계층이 깊으면 유리
.environment(cart)
// 받는 쪽: @Environment(Cart.self) private var cart
```

지금은 계층이 얕아 ①로 충분하다. [`@Environment` 문서](./environment-property-wrapper.md)에서 선택 기준을 다뤘다.

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
- [ ] `chapter-69`의 `Cart`를 `ObservableObject`에서 `@Observable`로 옮겨 본다.
- [ ] 그 과정에서 `@Published`와 `internal import Combine`이 불필요해지는 것을 확인한다.
- [ ] `CartView`의 `@ObservedObject`를 제거하고도 갱신이 되는지 확인한다.
- [ ] `CourseHome`의 `var cart = Cart()`에 `@State`를 붙이기 전후로 장바구니가 유지되는지 비교한다.
- [ ] `@StateObject`가 `@Observable` 타입도 받아 주는지 확인한다 (점진적 마이그레이션).
- [ ] `@Bindable`로 `@Observable` 객체의 프로퍼티에 바인딩을 만들어 본다.

## 공식 참고 자료

- [Apple: Observation](https://developer.apple.com/documentation/observation)
- [Apple: Observable() 매크로](https://developer.apple.com/documentation/observation/observable())
- [Apple: Observable 프로토콜](https://developer.apple.com/documentation/observation/observable)
- [Apple: ObservationIgnored()](https://developer.apple.com/documentation/observation/observationignored())
- [Apple: withObservationTracking(_:onChange:)](https://developer.apple.com/documentation/observation/withobservationtracking(_:onchange:))
- [Apple: ObservationRegistrar](https://developer.apple.com/documentation/observation/observationregistrar)
- [Apple: Managing model data in your app](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app)
- [Apple: Migrating from the Observable Object protocol to the Observable macro](https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro)
- [Apple: Bindable](https://developer.apple.com/documentation/swiftui/bindable)
- [Apple: ObservableObject (구형)](https://developer.apple.com/documentation/combine/observableobject)
- [Apple: view.environment(_:)](https://developer.apple.com/documentation/swiftui/view/environment(_:))
- [Apple: State](https://developer.apple.com/documentation/swiftui/state)
- [Apple: Environment](https://developer.apple.com/documentation/swiftui/environment)
