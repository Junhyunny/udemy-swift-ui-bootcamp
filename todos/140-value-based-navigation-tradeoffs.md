# 값 기반 네비게이션의 장단점 — 그리고 라우팅 값 설계

값 전달과 `navigationDestination`의 기본 동작은 [`value`와 `String.self`](./076-navigation-link-value-and-destination.md)에, 두 방식의 공존과 혼용 문제는 [두 방식의 공존](./078-navigation-link-two-styles-mixed.md)에, `path` 타입 선택은 [`NavigationPath`와 타입 배열](./075-navigation-path-and-typed-array.md)에 이미 정리했다.

**이 문서가 더하는 것은 넷이다.**

1. "목적지가 미리 만들어진다"가 **정확히 무엇을 뜻하는지** — SDK 시그니처로 확인한다
2. 값 기반의 **단점** — 기존 문서들은 장점 쪽에 기울어 있다
3. **라우팅 값 설계** — `String`을 라우팅 값으로 쓰는 것이 왜 애매한가
4. `navigationDestination(item:)` — 어느 문서에도 없는 세 번째 선택지

시그니처는 **iPhoneOS 26.5 SDK의 `SwiftUI.swiftinterface`에서 직접 인용**했다.

## 1부 — "미리 만들어진다"는 정확히 무엇인가

### 근거: 시그니처를 보면 답이 나온다

목적지 직접 지정 방식은 클로저로 써도 **클로저가 보관되지 않는다.**

```swift
@_alwaysEmitIntoClient public init(@ViewBuilder destination: () -> Destination,
                                   @ViewBuilder label: () -> Label) {
    self.init(destination: destination(), label: label)   // ← 즉시 호출한다
}

public init(destination: Destination, @ViewBuilder label: () -> Label)
```

`destination()`을 **`init` 안에서 바로 호출**해 값으로 바꿔 넘긴다. `{ }`로 감쌌으니 지연될 것 같지만 아니다. 트레일링 클로저는 문법일 뿐이고 실제로는 값이다.

값 기반은 반대다. 확장 자체의 제약을 보면 분명하다.

```swift
extension SwiftUI.NavigationLink where Destination == Never {
    nonisolated public init<P>(value: P?, @ViewBuilder label: () -> Label) where P : Hashable
}
```

**`Destination == Never`** — 목적지 타입이 아예 존재하지 않는다. 만들어질 것이 없으니 만들어지지 않는다.

받는 쪽은 진짜 클로저다.

```swift
nonisolated public func navigationDestination<D, C>(
    for data: D.Type,
    @ViewBuilder destination: @escaping (D) -> C
) -> some View where D : Hashable, C : View
```

`@escaping (D) -> C`이므로 보관됐다가 **실제로 push될 때 호출**된다.

### 무엇이 실행되고 무엇이 실행되지 않나

여기가 중요하다. 목적지가 "만들어진다"고 해서 화면이 그려지는 것은 아니다.

| | 링크를 그릴 때 | 실제로 이동할 때 |
| --- | --- | --- |
| 목적지 `struct`의 `init` | **실행됨** | — |
| `init`에 넘긴 인자 표현식 | **평가됨** | — |
| 목적지의 `body` | 실행 안 됨 | 실행됨 |
| `@State` 저장소 설치 | 안 됨 | 됨 |

**비용은 `body`가 아니라 "인자 표현식 평가"에 있다.** 그래서 목적지가 `Text("Hello")`면 사실상 공짜고, 초기화 과정에서 무언가를 새로 만드는 뷰면 그것이 매번 만들어진다.

여기서 프로퍼티 래퍼별로 갈린다. 시그니처가 다르기 때문이다.

```swift
// StateObject — @autoclosure 라서 지연된다
@inlinable nonisolated public init(wrappedValue thunk: @autoclosure @escaping () -> ObjectType)

// State(initialValue:) — 평범한 값이라 즉시 평가된다
@_alwaysEmitIntoClient public init(initialValue value: Value)
```

**생성자 주입 + `State(initialValue:)` 조합을 쓰는 뷰를 `NavigationLink(destination:)`의 목적지로 두면, 부모 `body`가 재평가될 때마다 그 객체가 새로 만들어진다.** 만들어진 것은 push된 하나만 쓰이고 나머지는 버려진다.

누수는 아니다. 버려진 값은 정상적으로 해제된다. **낭비일 뿐이다.** 다만 그 초기화가 네트워크 호출이나 무거운 계산을 포함하면 낭비가 아니라 버그가 된다.

이 저장소에서 확인할 수 있는 형태다.

```swift
// chapter-59 — 목적지가 Text 라서 비용이 사실상 없다
NavigationLink("first page") { Text("Hello View") }

// chapter-60 — 값 기반. 탭할 때만 DestinationView 가 만들어진다
NavigationLink(course.name, value: course)
.navigationDestination(for: DevTechieCourse.self) { course in
    DestinationView(title: course.name)
}
```

## 2부 — 장점

| 장점 | 근거 |
| --- | --- |
| 목적지가 **필요할 때만** 생성 | `Destination == Never` + `@escaping` 클로저 |
| `path`로 **프로그래밍 이동** | 값이 `path`에 쌓인다 |
| **딥링크·상태 복원** | `path`에 값을 넣으면 화면이 재구성된다 |
| **목적지 정의가 한 곳** | 같은 화면으로 가는 링크가 여러 개여도 정의는 하나 |
| 링크가 **가벼워진다** | 목록 100개여도 목적지 0개 |
| **테스트 가능** | 이동을 "값 추가"로 검증할 수 있다 |

마지막 항목이 과소평가되는 편이다. 목적지 직접 방식은 이동이 SwiftUI 내부 상태라 밖에서 관찰할 수 없다. 값 기반은 `path`가 그냥 배열이므로 **뷰를 띄우지 않고도 "탭하면 이 값이 쌓인다"를 단위 테스트로 검증**할 수 있다. [의존성 주입 문서](./123-dependency-injection-for-testing.md)의 접근과 같은 맥락이다.

## 3부 — 단점

기존 문서들이 덜 다룬 쪽이다.

### ① 값이 `Hashable`이어야 한다

`where P : Hashable` 제약이다. 그런데 이 제약은 생각보다 자주 걸린다.

- 클로저를 목적지에 넘기고 싶을 때 → 불가능하다
- 뷰모델이나 참조 타입을 그대로 넘기고 싶을 때 → `Hashable` 구현이 애매하다
- `id`에 `UUID()`가 들어간 모델 → 매번 해시가 달라져 매칭이 깨진다

셋째가 이 저장소에서 실제로 문제가 된 사례다. `chapter-57`과 `chapter-60`의 `FIXME`가 지적하는 내용으로, `static var` 계산 프로퍼티라 접근할 때마다 새 `UUID`가 생겨 `path`에 넣은 값과 `List`가 그리는 값이 서로 달라진다. [Hashable과 id](./026-hashable-id-and-collisions.md) 참조.

### ② 등록이 타입 단위라서 전역적이다

`navigationDestination(for: String.self)`는 **"이 스택에서 `String`이 push되면"** 이라는 규칙이다. 특정 링크와 묶이지 않는다.

- 같은 타입을 두 번 등록하면 하나가 무시된다
- 서로 다른 의미의 값이 같은 타입이면 구분되지 않는다
- 화면 A의 "문자열"과 화면 B의 "문자열"이 충돌한다

`chapter-57`이 이 문제를 그대로 보여 준다. `String`과 `Color`를 각각 등록해 두었는데, `String`을 쓰는 다른 화면이 생기면 즉시 꼬인다.

### ③ 실패가 조용하다

등록되지 않은 타입을 push하면 **아무 일도 일어나지 않는다.** 에러도, 경고도, 크래시도 없다. 링크를 눌렀는데 반응이 없을 뿐이다. 목적지 직접 방식은 이런 실패 자체가 불가능하다 — 목적지가 컴파일 타임에 붙어 있기 때문이다.

lazy 컨테이너 안에 `navigationDestination`을 넣었을 때도 같은 증상이다. 이 경우는 콘솔 경고가 나온다.

> There's a misplaced `navigationDestination(for:destination:)` modifier for type Destination. It will be ignored in a future release.

### ④ 링크와 목적지가 멀어진다

코드를 읽을 때 "이 링크를 누르면 어디로 가는가"가 한눈에 안 보인다. 링크는 값만 넘기고, 목적지는 스택 어딘가에 있다. 화면이 커질수록 추적 비용이 늘어난다.

Apple의 권고는 절충이다.

> Consider putting destinations near the corresponding links to make maintenance easier, but remember not to put them inside of lazy containers.

### ⑤ 보일러플레이트가 는다

링크 하나 만들려고 값 타입을 정의하고, `Hashable`을 붙이고, `navigationDestination`을 등록해야 한다. **화면이 두세 개뿐이면 목적지 직접 지정이 더 읽기 쉽다.**

## 4부 — 라우팅 값 설계: `String`은 왜 애매한가

`NavigationLink(value: roomCode)` + `navigationDestination(for: String.self)`는 동작한다. 하지만 권장하기 어렵다.

**문제는 타입이 의미를 담지 못한다는 점이다.**

```swift
.navigationDestination(for: String.self) { code in
    CallingView(roomCode: code)
}
```

이 등록은 "이 스택에서 **모든 문자열**은 통화 화면으로 간다"는 뜻이 된다. 나중에 검색어나 사용자 이름을 push하고 싶어지면 그 순간 무너진다. 3부 ②의 전형적인 사례다.

전용 타입을 쓰면 이 문제가 사라진다.

```swift
struct RoomCode: Hashable {
    let value: String
}

NavigationLink(value: RoomCode(value: roomCode)) { Text("통화 시작") }

.navigationDestination(for: RoomCode.self) { room in
    CallingView(roomCode: room.value)
}
```

타입이 곧 라우팅 규칙이 된다. 비용은 `struct` 하나다.

화면이 여러 개면 `enum`으로 모으는 편이 낫다.

```swift
enum Route: Hashable {
    case calling(roomCode: String)
    case settings
    case profile(userID: String)
}

.navigationDestination(for: Route.self) { route in
    switch route { ... }
}
```

`chapter-51`이 이 형태를 쓴다. 등록이 하나로 줄고, `switch`가 모든 경로를 한눈에 보여 주며, 새 화면을 빠뜨리면 컴파일러가 잡아 준다.

**상태 복원까지 원하면 `Codable`을 더한다.** SDK에 전용 오버로드가 따로 있다.

```swift
nonisolated public init<P>(value: P?, @ViewBuilder label: () -> Label)
    where P : Decodable, P : Encodable, P : Hashable
```

`NavigationPath`의 `CodableRepresentation`으로 경로를 저장·복원하려면 이 제약을 만족해야 한다. 자세한 것은 [075 문서](./075-navigation-path-and-typed-array.md)의 상태 저장·복원 절에 있다.

선택 기준은 단순하다.

| 상황 | 라우팅 값 |
| --- | --- |
| 화면 1~2개, 딥링크 없음 | 목적지 직접 지정 (값 안 씀) |
| 모델을 그대로 넘기면 됨 | 그 모델 타입 (`Hashable` + 안정적 `id`) |
| 의미가 다른 문자열·숫자 | **전용 `struct`** |
| 화면 3개 이상, 딥링크 있음 | **`enum Route`** |
| 경로 저장·복원까지 | `enum Route: Codable & Hashable` |

## 5부 — 세 번째 선택지: `navigationDestination(item:)`

두 방식 사이에 낀 형태가 하나 더 있다. 어느 기존 문서에도 없다.

```swift
nonisolated public func navigationDestination<D, C>(
    item: Binding<Optional<D>>,
    @ViewBuilder destination: @escaping (D) -> C
) -> some View where D : Hashable, C : View
```

`path`가 아니라 **옵셔널 바인딩 하나**로 화면 하나를 제어한다.

```swift
@State private var selectedRoom: RoomCode?

.navigationDestination(item: $selectedRoom) { room in
    CallingView(roomCode: room.value)
}

Button("통화 시작") { selectedRoom = RoomCode(value: code) }   // 이동
// selectedRoom = nil 이면 돌아온다
```

| | `for:` | `item:` |
| --- | --- | --- |
| 제어 단위 | 스택 전체(`path`) | 화면 하나 |
| 상태 | 배열 | 옵셔널 하나 |
| 여러 단계 push | 가능 | 한 단계 |
| 적합한 경우 | 라우팅 체계 전반 | **단발성 이동** |

`sheet(item:)`과 모양이 같아서 익숙하다. "특정 조건이 만족되면 한 화면으로 보낸다" 정도에는 `path` 전체를 도입하는 것보다 가볍다. 목적지가 지연 생성되는 장점은 그대로 가져간다.

## 6부 — 정리

```text
목적지 직접 지정 (NavigationLink { Destination() })
  ✅ 읽기 쉽다, 링크와 목적지가 붙어 있다, 실패가 없다
  ❌ 부모 body 마다 목적지 값 생성, path 에 안 남음, 딥링크 불가
  → 화면 1~2개, 목적지가 가벼울 때

값 기반 (NavigationLink(value:) + navigationDestination(for:))
  ✅ 지연 생성, path 제어, 딥링크·복원, 정의 한 곳, 테스트 가능
  ❌ Hashable 필요, 타입 단위 등록, 조용한 실패, 링크-목적지 분리
  → 화면 3개 이상, 딥링크·복원이 필요할 때

navigationDestination(item:)
  → 단발성 이동 하나를 옵셔널로 제어하고 싶을 때

라우팅 값은 String 말고 전용 타입이나 enum Route 로
```

**경험칙 — 먼저 목적지 직접 지정으로 시작하고, 딥링크·복원·프로그래밍 이동 중 하나가 필요해지는 순간 값 기반으로 옮긴다.** 그때 라우팅 값을 `enum`으로 설계하면 이후 화면이 늘어도 구조가 버틴다.

## 학습 체크리스트

- [ ] 목적지 뷰의 `init`에 `print`를 넣고, `NavigationLink(destination:)`으로 링크만 그렸을 때 몇 번 찍히는지 센다.
- [ ] 같은 뷰의 `body`에도 `print`를 넣어 `init`만 실행되고 `body`는 실행되지 않는 것을 확인한다.
- [ ] 부모에 `@State` 카운터를 두고 값을 바꿔 `body`를 재평가시킨 뒤, 목적지 `init`이 다시 찍히는지 본다.
- [ ] 같은 링크를 `NavigationLink(value:)`로 바꾸고 `init`이 탭할 때만 찍히는지 비교한다.
- [ ] `List`에 행 100개를 만들어 두 방식의 `init` 호출 횟수를 비교한다.
- [ ] `navigationDestination`을 `List` 안으로 옮겨 콘솔 경고와 이동 실패를 확인한다.
- [ ] 등록하지 않은 타입을 `path`에 넣고 아무 일도 일어나지 않는 것을 확인한다.
- [ ] 같은 타입에 `navigationDestination`을 두 번 등록해 어느 쪽이 이기는지 확인한다.
- [ ] `chapter-57`의 `exampleData`를 `static let`으로 바꾸고 `path` 초기값이 제대로 복원되는지 본다.
- [ ] `chapter-60`을 `enum Route`를 쓰도록 고쳐 본다.
- [ ] `String` 대신 전용 `struct`를 라우팅 값으로 만들어 등록 충돌이 사라지는지 확인한다.
- [ ] `navigationDestination(item:)`으로 단발성 이동을 만들고 `nil` 대입으로 돌아오는지 본다.
- [ ] `enum Route: Codable & Hashable`로 `NavigationPath`를 저장·복원해 본다.

## 공식 참고 자료

- [Apple: NavigationLink](https://developer.apple.com/documentation/swiftui/navigationlink)
- [Apple: NavigationLink.init(value:label:)](https://developer.apple.com/documentation/swiftui/navigationlink/init(value:label:))
- [Apple: navigationDestination(for:destination:)](https://developer.apple.com/documentation/swiftui/view/navigationdestination(for:destination:))
- [Apple: navigationDestination(item:destination:)](https://developer.apple.com/documentation/swiftui/view/navigationdestination(item:destination:))
- [Apple: NavigationStack](https://developer.apple.com/documentation/swiftui/navigationstack)
- [Apple: NavigationPath](https://developer.apple.com/documentation/swiftui/navigationpath)
- [Apple: Migrating to new navigation types](https://developer.apple.com/documentation/swiftui/migrating-to-new-navigation-types)
- [Apple: StateObject](https://developer.apple.com/documentation/swiftui/stateobject)
- [Apple: State.init(initialValue:)](https://developer.apple.com/documentation/swiftui/state/init(initialvalue:))
- [WWDC22: The SwiftUI cookbook for navigation](https://developer.apple.com/videos/play/wwdc2022/10054/)
