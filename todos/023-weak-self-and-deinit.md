# 클로저의 `@escaping`, `self`, `[weak self]`와 객체 수명

ARC와 순환 참조의 기본 원리는 [Swift 메모리 구조](./022-swift-memory-model.md)에 정리했다. 이 문서는 클로저의 수명, `self` 캡처, 객체 해제를 함께 다룬다. 타입 값 `SomeType.self`와 대문자 `Self`는 [메타타입 문서](./035-metatype-and-self.md)의 별개 주제다.

## 질문이 나온 코드

`chapter-80/chapter-80/ViewModels/ViewModel.swift`

```swift
.sink { [weak self] in
    print($0)
    self?.exchangeRate = $0
}
.store(in: &cancellableSet)
```

```swift
deinit {
    cancellableSet.forEach { $0.cancel() }
}
```

## 1부 — `@escaping`과 `self`

### `@escaping`은 언제 필요한가

함수의 클로저 파라미터는 기본적으로 함수 호출 안에서만 사용한다. 함수가 반환된 뒤에도 클로저를 저장하거나 다른 escaping 파라미터로 전달하려면 파라미터 타입에 `@escaping`을 붙인다. 클로저를 저장하는 **프로퍼티 선언 자체**에는 붙이지 않는다.

```swift
final class HandlerStore {
    var handlers: [() -> Void] = []

    func add(_ handler: @escaping () -> Void) {
        handlers.append(handler)
    }
}
```

`add`가 끝난 뒤에 `handler`가 실행될 수 있으므로 escaping이다. `@escaping`을 지우면 저장할 수 없다는 컴파일 오류가 난다. 반대로 호출 중에만 실행하는 `func run(_ action: () -> Void) { action() }`에는 필요하지 않다. `@escaping`은 **클로저의 수명에 관한 선언**이며, 그 자체로 순환 참조가 생겼다는 뜻은 아니다.

`chapter-47/chapter-47/ContentView.swift`의 `measureSzie(perform:)`도 받은 `action`을 `onPreferenceChange`의 escaping 파라미터로 넘긴다.

```swift
func measureSzie(perform action: @escaping (CGSize) -> Void) -> some View {
    modifier(MeasuringSizeModifier())
        .onPreferenceChange(SizePreferenceKey.self, perform: action)
}

// 호출하는 쪽
.measureSzie { size in viewSize = size }
```

`measureSzie`는 `action`을 직접 실행하지 않고 `onPreferenceChange`의 escaping 파라미터로 넘긴다. 크기가 바뀔 때 나중에 호출될 수 있으므로 전달하는 쪽에도 `@escaping`이 필요하다. `Button`의 `action` 역시 탭할 때 실행되는 escaping 클로저다. `label`이나 `VStack`의 `content`는 뷰 내용을 구성하는 클로저다. UI의 클로저 문법은 [클로저와 result builder](./040-closures-and-view-builders.md), 크기 전달 흐름은 [PreferenceKey](./067-preference-key-and-onpreferencechange.md)에 정리했다.

### 클로저 안의 `self`

소문자 `self`는 현재 인스턴스를 가리킨다. 클래스의 인스턴스 프로퍼티나 메서드를 일반적인 **escaping 클로저** 안에서 참조할 때는 `self.`를 명시해 캡처를 드러낸다. 비escaping 클로저에서는 암묵적으로 참조할 수 있다.

```swift
func run(_ action: () -> Void) { action() }

final class Counter {
    var count = 0

    func update(store: HandlerStore) {
        store.add { self.count += 1 }  // 강한 캡처
        run { count += 1 }              // 비escaping: 암묵적 self
    }
}
```

`[self]`를 캡처 리스트에 적으면 클로저 안에서 `self.`를 생략할 수도 있지만 **강한 캡처**라는 점은 같다. `self.`를 쓰거나 `@escaping`을 붙인다고 항상 누수가 나는 것은 아니다. 실제로 누수되는지는 아래처럼 소유 관계가 다시 `self`로 돌아오는지 확인해야 한다.

## 2부 — `[weak self]`

### 무엇인가 — 캡처 리스트

`[weak self]`는 클로저의 **캡처 리스트(capture list)** 다. "이 클로저가 `self`를 약하게 참조한다"는 선언이다.

```swift
{ [weak self] in ... }
//  ↑ 캡처 리스트
```

### 왜 필요한가 — 순환 참조

**클로저는 참조 타입이고, 캡처한 것을 강하게 붙잡는다.** 이 성질이 문제를 만든다.

```swift
final class ViewModel {
    private var cancellableSet: Set<AnyCancellable> = []

    func fetchRates() {
        publisher
            .sink { self.exchangeRate = $0 }    // ⚠️ self를 강하게 캡처
            .store(in: &cancellableSet)          // 그 클로저를 self가 보관
    }
}
```

```text
ViewModel ──(cancellableSet)──→ AnyCancellable ──→ 클로저 ──(self)──→ ViewModel
   ↑                                                                      │
   └──────────────────────────────────────────────────────────────────────┘
                          순환 — 둘 다 해제되지 않는다
```

`ViewModel`이 클로저를 붙잡고, 클로저가 `ViewModel`을 붙잡는다. **참조 카운트가 서로 1로 남아 영원히 해제되지 않는다.** [ARC는 순환을 스스로 못 푼다](./022-swift-memory-model.md).

`[weak self]`가 한쪽 화살표를 끊는다.

```text
ViewModel ──(cancellableSet)──→ AnyCancellable ──→ 클로저 ┄┄(weak self)┄┄> ViewModel
                                                              (카운트 증가 없음)
```

### `self?`가 되는 이유

`weak`으로 캡처하면 **옵셔널이 된다.** 대상이 이미 해제됐을 수 있기 때문이다.

```swift
.sink { [weak self] in
    self?.exchangeRate = $0      // self가 nil이면 아무 일도 안 한다
}
```

`ViewModel`이 해제된 뒤 응답이 도착하면 `self`는 `nil`이고, 옵셔널 체이닝으로 조용히 넘어간다. **크래시하지 않는다는 것이 핵심 이점이다.**

여러 줄에서 `self`를 써야 하면 `guard`로 풀어 쓴다.

```swift
.sink { [weak self] value in
    guard let self else { return }
    exchangeRate = value
    updateUI()
}
```

[`guard let self`](./158-conditional-statements-complete-guide.md)의 축약 문법이고, 이후에는 옵셔널이 아닌 `self`를 쓸 수 있다.

### `weak`과 `unowned`

| | `weak` | `unowned` |
| --- | --- | --- |
| 카운트 증가 | 안 함 | 안 함 |
| 대상 해제 후 | **`nil`** | **크래시** |
| 타입 | `Optional` | 비옵셔널 |
| 쓸 때 | 대상이 먼저 사라질 수 있다 | 대상이 자기보다 오래 산다고 확신 |

`unowned`는 클로저가 실행될 때 대상이 반드시 살아 있다고 보장할 수 있을 때만 쓴다. 대상이 먼저 사라질 수 있는 콜백이라면 `weak`이 적절하다. 다만 클로저가 `self`를 붙잡아야 작업이 끝나는 경우도 있으므로, 수명과 소유 관계를 확인해 선택한다.

### 언제 `[weak self]`가 불필요한가

**모든 클로저에 붙일 필요는 없다.** 순환이 생기지 않으면 오히려 불필요한 옵셔널 처리만 늘어난다.

**① 즉시 실행되고 저장되지 않는 클로저**

```swift
items.map { self.transform($0) }        // 즉시 끝난다 — 불필요
```

**② 끝나는 `Task { }` 안 — 대체로 불필요**

```swift
Task {
    exchangeRate = try await service.fetch()    // weak self 없이도 대체로 문제없다
}
```

작업이 끝나면 `Task`가 캡처한 참조도 해제된다. 그러나 작업이 오래 실행되거나 끝나지 않는 반복을 포함하면 객체의 수명도 길어진다. 이 경우 작업 취소 시점과 소유 관계를 따로 확인한다. [Combine과 async/await 비교](./114-combine-vs-async-await.md)도 참고한다.

**③ SwiftUI `View`의 클로저**

`View` 자체는 `struct`이므로 뷰 값의 `self`를 캡처한다고 클래스 인스턴스 사이의 순환 참조가 생기지는 않는다. 다만 클로저가 별도의 클래스 객체를 캡처한다면 그 객체의 소유 관계는 따로 확인한다.

```swift
Button("탭") {
    counter += 1        // weak self 불필요
}
```

**④ 이 예제처럼 저장되는 클로저 — 여기서는 필요하다**

`sink`의 클로저가 `AnyCancellable`에 담기고, 그것을 `self`가 보관하므로 순환이 성립한다.

### 판단 기준

```text
클로저가 저장되는가? (프로퍼티, 컬렉션, 구독)
  ├─ 예 → 그 저장 위치를 self가 소유하는가?
  │        ├─ 예 → 클로저가 self를 강하게 캡처하는가?
  │        │        ├─ 예 → 순환을 끊거나 캡처 방식을 바꾼다 ← 이 예제
  │        │        └─ 아니오 → 이 경로의 순환은 없다
  │        └─ 아니오 → 대체로 불필요
  └─ 아니오 (즉시 실행) → 불필요
```

## 3부 — `deinit`

### 무엇이고 언제 실행되나

> A *deinitializer* is called **immediately before a class instance is deallocated**. You write deinitializers with the `deinit` keyword, similar to how initializers are written with the `init` keyword. **Deinitializers are only available on class types.**

**인스턴스가 해제되기 직전에 호출된다.** `class`에만 있다.

```swift
deinit {
    // 정리 작업
}
```

**규칙 몇 가지**

- 클래스당 **하나만** 정의할 수 있다
- 파라미터가 없고 괄호도 쓰지 않는다
- 직접 호출할 수 없다. 시스템이 부른다
- `struct`, `enum`에는 없다 — 참조 카운팅 대상이 아니기 때문이다

### 언제 실행되나 — ARC가 결정한다

> Swift automatically deallocates your instances when they're no longer needed, to free up resources. Swift handles the memory management of instances through *automatic reference counting* (*ARC*).

**참조 카운트가 0이 되는 순간**이다. [Swift 메모리 구조](./022-swift-memory-model.md)에서 다룬 대로 **시점이 결정적**이다.

```swift
var vm: ViewModel? = ViewModel()
vm = nil                    // ← 이 순간 deinit 호출
```

JVM의 `finalize`가 "언젠가" 불리는 것과 다르다. Swift는 마지막 강한 참조가 사라지는 즉시 부른다.

**순환 참조가 있으면 절대 불리지 않는다.** 그래서 `deinit`에 `print`를 넣는 것이 누수를 확인하는 가장 간단한 방법이다.

```swift
deinit {
    print("ViewModel 해제됨")    // 안 찍히면 누수를 의심한다
}
```

### 무엇을 넣나

> Typically you don't need to perform manual cleanup when your instances are deallocated. **However, when you are working with your own resources, you might need to perform some additional cleanup yourself.** For example, if you create a custom class to open a file and write some data to it, you might need to close the file before the class instance is deallocated.

ARC가 메모리는 알아서 처리하므로, **메모리가 아닌 자원**을 정리한다.

- 열어 둔 파일 닫기
- 타이머 무효화 (`timer.invalidate()`)
- 옵저버 제거 (`NotificationCenter.removeObserver`)
- 소켓·스트림 종료
- 임시 파일 삭제

### 이 코드의 `deinit`은 중복이다

```swift
deinit {
    cancellableSet.forEach { $0.cancel() }
}
```

**`AnyCancellable`은 해제될 때 자동으로 `cancel()`을 호출한다.**

> An `AnyCancellable` instance automatically calls `cancel()` when deinitialized.

`ViewModel`이 해제되면 `cancellableSet`도 해제되고, 그 안의 `AnyCancellable`들이 각자 취소한다. **이 `deinit`을 지워도 동작이 같다.**

써서 나쁠 것은 없다. 의도가 드러나고, `print`를 추가해 누수를 확인하기 좋은 자리이기도 하다. 다만 **"이게 없으면 누수된다"는 오해는 피해야 한다.**

관련 내용은 [구독 수명 관리 문서](./112-combine-cancellable-and-store.md)에 정리했다.

### `deinit`에서 주의할 점

**① 다른 객체를 참조하면 안 될 수도 있다**

해제 중인 상태이므로 다른 객체의 상태를 신뢰하기 어렵다.

**② `self`를 비동기 작업으로 넘기지 않는다**

`deinit`에서 `self`를 캡처하는 `Task`를 만들면 해제 중인 인스턴스가 `deinit` 밖으로 탈출할 수 있어 컴파일러가 막는다. 비동기 정리가 필요하다면 인스턴스가 살아 있을 때 별도의 종료 메서드에서 수행한다.

**③ 실행 스레드가 보장되지 않는다**

마지막 참조가 사라진 스레드에서 불린다. UI를 건드리면 안 된다. [Swift 액터 완전 정복](./153-swift-actor-complete-guide.md) 참조.

**④ 상속 관계에서는 자동으로 연쇄된다**

하위 클래스의 `deinit`이 끝나면 상위 클래스의 `deinit`이 자동 호출된다. `super.deinit`을 직접 부를 필요가 없다.

### 정리

```text
@escaping
  함수 반환 뒤에도 클로저를 사용할 수 있는 파라미터 선언
  저장되거나 다른 escaping 파라미터로 전달될 때 필요

self
  현재 인스턴스. escaping 클로저에서 강하게 캡처할 수 있음
  명시적 self와 [self] 모두 강한 캡처

[weak self]
  클로저가 self를 약하게 캡처 → 순환 참조를 끊는다
  self가 옵셔널이 되어 해제 후에도 안전하다
  고려할 경우: self가 소유한 저장 클로저가 다시 self를 강하게 캡처할 때
  대체로 불필요한 경우: 즉시 실행 클로저, 끝나는 Task, SwiftUI View 값 자체

deinit
  인스턴스 해제 직전 호출. class에만 있다
  ARC가 참조 카운트 0이 되는 순간 부른다 (시점이 결정적)
  메모리가 아닌 자원 정리에 쓴다 (파일, 타이머, 옵저버)
  print를 넣어 누수를 확인하는 것이 실용적
  이 코드의 forEach cancel()은 중복 — AnyCancellable이 자동 호출
```

## Xcode Playground에서 직접 실행하기

아래 코드 전체를 macOS 또는 iOS의 **Blank Playground**에 붙여 넣고 실행한다. SwiftUI와 Combine을 import하지 않아도 된다. 출력은 오른쪽 결과 표시 영역보다 **콘솔**에서 순서대로 확인하기 쉽다.

```swift
func performNow(_ action: () -> Void) {
    action()
}

final class DeferredActions {
    private var action: (() -> Void)?

    func save(_ action: @escaping () -> Void) {
        self.action = action
    }

    func fire() { action?() }
    func clear() { action = nil }
}

// 1. 호출 중 실행하는 클로저와 나중에 실행하는 클로저
performNow { print("즉시 실행") }

let deferred = DeferredActions()
deferred.save { print("나중에 실행") }
print("save 반환")
deferred.fire()

final class Owner {
    let name: String
    let actions = DeferredActions()

    init(_ name: String) { self.name = name }
    deinit { print("\(name) deinit") }

    func report() { print("\(name) 실행") }

    func startStrong() {
        actions.save { self.report() }
    }

    func registerWeak(on store: DeferredActions) {
        store.save { [weak self] in
            guard let self else {
                print("소유자 없음")
                return
            }
            self.report()
        }
    }
}

// 2. Owner → actions → 클로저 → Owner 순환 참조
weak var strongProbe: Owner?
do {
    let owner = Owner("strong")
    strongProbe = owner
    owner.startStrong()
    owner.actions.fire()
}
print("strong 살아 있음: \(strongProbe != nil)")
strongProbe?.actions.clear()  // 순환을 직접 끊는다
print("strong 해제됨: \(strongProbe == nil)")

// 3. 약한 캡처: 클로저를 Owner가 보관해도 순환이 없다
weak var weakProbe: Owner?
do {
    let owner = Owner("weak")
    weakProbe = owner
    owner.registerWeak(on: owner.actions)
    owner.actions.fire()
}
print("weak 해제됨: \(weakProbe == nil)")

// 4. 클로저가 외부에 남아 있어도 해제된 self는 nil이 된다
let externalStore = DeferredActions()
do {
    let owner = Owner("external")
    owner.registerWeak(on: externalStore)
    externalStore.fire()
}
externalStore.fire()
```

콘솔에는 `즉시 실행` → `save 반환` → `나중에 실행` 순서가 먼저 나온다. `strong`은 지역 범위를 나간 뒤에도 살아 있어 `strong 살아 있음: true`가 찍힌다. `clear()`로 순환을 끊으면 `strong deinit`이 나온다. `weak`은 범위를 나갈 때 `deinit`이 호출된다. 마지막 `externalStore.fire()`는 해제된 객체를 되살리지 않고 `소유자 없음`을 출력한다.

`startStrong()`의 `self.report()`를 `report()`로 바꾸면 escaping 클로저에서 명시적 `self`가 필요하다는 컴파일 오류를 볼 수 있다. 3번의 약한 캡처를 강한 캡처로 비교하려면 `registerWeak(on:)`에서 `[weak self]`를 `[self]`로 바꾸고 `guard let self else { ... }` 부분을 지운다. 그러면 `weak 해제됨: false`로 달라진다. 이 경우 Playground 실행이 끝나도 순환 참조가 남으므로 비교한 뒤 코드를 원래대로 돌린다.

## 학습 체크리스트

- [ ] Playground의 `strongProbe`와 `weakProbe` 출력 및 `deinit` 순서를 비교한다.
- [ ] 외부에 남은 클로저를 호출해 `guard let self`의 `nil` 분기를 확인한다.
- [ ] 클로저를 배열에 저장하는 함수에서 `@escaping`을 지우고 컴파일 오류를 확인한다.
- [ ] `measureSzie(perform:)`에서 `@escaping`을 지우고 오류를 확인한다.
- [ ] `measureSzie(perform:)`의 콜백에 `print`를 넣어 호출 시점을 확인한다.
- [ ] 콜백을 즉시 실행하는 함수와 저장하는 함수를 만들어 호출 시점을 비교한다.
- [ ] `typealias SizeHandler = (CGSize) -> Void`로 클로저 타입을 분리해 본다.
- [ ] escaping 클로저에서 `self.`와 `[self]`를 각각 써 보고 캡처 관계를 설명한다.
- [ ] 비escaping 클로저에서 인스턴스 멤버를 `self.` 없이 사용한다.
- [ ] `[weak self]`를 지우고 `deinit`의 `print`가 찍히지 않는 것을 확인한다 (순환 참조).
- [ ] `[weak self]`를 되살려 `deinit`이 실행되는지 확인한다.
- [ ] `self?`를 `guard let self else { return }`로 바꿔 본다.
- [ ] `[weak self]`를 `[unowned self]`로 바꾸고 위험을 이해한다.
- [ ] `deinit`에 `print("해제됨")`을 넣고 화면을 나갔을 때 찍히는지 본다.
- [ ] `deinit`의 `forEach { cancel() }`을 지우고도 정상 동작하는지 확인한다.
- [ ] `struct`에 `deinit`을 넣어 보고 컴파일 에러를 확인한다.
- [ ] `var vm: ViewModel? = ViewModel(); vm = nil`로 `deinit` 시점을 확인한다.
- [ ] SwiftUI `Button`의 클로저에 `[weak self]`가 불필요한 이유를 설명한다.
- [ ] `Task { }` 안에서 `self`를 강하게 캡처해도 순환이 남지 않는 이유를 설명한다.
- [ ] `deinit`에서 `Task { }`를 만들어 보고 왜 위험한지 생각해 본다.
- [ ] `ViewModel`을 async/await로 바꿔 `[weak self]`가 사라지는 것을 확인한다.

## 공식 참고 자료

- [Swift 공식 문서: Closures — Escaping Closures](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/closures/#Escaping-Closures)
- [Swift 공식 문서: Attributes — escaping](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/attributes/#escaping)
- [Swift 공식 문서: Deinitialization](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/deinitialization/)
- [Swift 공식 문서: ARC — Strong Reference Cycles for Closures](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting/#Strong-Reference-Cycles-for-Closures)
- [Swift 공식 문서: ARC — Resolving Strong Reference Cycles for Closures](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting/#Resolving-Strong-Reference-Cycles-for-Closures)
- [Swift 공식 문서: ARC — Weak References](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting/#Weak-References)
- [Swift 공식 문서: ARC — Unowned References](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting/#Unowned-References)
- [Swift 공식 문서: Closures — Capturing Values](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/closures/#Capturing-Values)
- [Swift 공식 문서: Expressions — Capture Lists](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/expressions/#Capture-Lists)
- [Apple: AnyCancellable](https://developer.apple.com/documentation/combine/anycancellable)
- [Apple: Task](https://developer.apple.com/documentation/swift/task)
