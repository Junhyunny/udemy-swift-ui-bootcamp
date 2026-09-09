# `[weak self]`와 `deinit` — 객체가 언제 사라지나

ARC와 순환 참조는 [Swift 메모리 구조](./swift-memory-model.md)에 정리했다. 이 문서는 **클로저 캡처와 `deinit`** 을 다룬다.

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

## 1부 — `[weak self]`

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

`ViewModel`이 클로저를 붙잡고, 클로저가 `ViewModel`을 붙잡는다. **참조 카운트가 서로 1로 남아 영원히 해제되지 않는다.** [ARC는 순환을 스스로 못 푼다](./swift-memory-model.md).

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

[`guard let self`](./guard-keyword.md)의 축약 문법이고, 이후에는 옵셔널이 아닌 `self`를 쓸 수 있다.

### `weak`과 `unowned`

| | `weak` | `unowned` |
| --- | --- | --- |
| 카운트 증가 | 안 함 | 안 함 |
| 대상 해제 후 | **`nil`** | **크래시** |
| 타입 | `Optional` | 비옵셔널 |
| 쓸 때 | 대상이 먼저 사라질 수 있다 | 대상이 자기보다 오래 산다고 확신 |

**기본은 `weak`이다.** `unowned`가 조금 빠르지만 확신이 틀리면 크래시한다. 네트워크 응답처럼 **언제 올지 모르는 콜백**에는 반드시 `weak`을 쓴다.

### 언제 `[weak self]`가 불필요한가

**모든 클로저에 붙일 필요는 없다.** 순환이 생기지 않으면 오히려 불필요한 옵셔널 처리만 늘어난다.

**① 즉시 실행되고 저장되지 않는 클로저**

```swift
items.map { self.transform($0) }        // 즉시 끝난다 — 불필요
```

**② `Task { }` 안 — 대체로 불필요**

```swift
Task {
    exchangeRate = try await service.fetch()    // weak self 없이도 대체로 문제없다
}
```

`Task`는 작업이 끝나면 `self` 참조를 놓는다. 순환이 남지 않는다. [Combine과 async/await 비교](./combine-vs-async-await.md)에서 언급한 async/await의 이점이 이것이다.

**③ SwiftUI `View`의 클로저**

`View`는 `struct`라 참조 타입이 아니다. 애초에 `self`를 강하게 캡처하는 순환이 생기지 않는다.

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
  │        ├─ 예 → [weak self] 필요       ← 이 예제
  │        └─ 아니오 → 대체로 불필요
  └─ 아니오 (즉시 실행) → 불필요
```

## 2부 — `deinit`

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

**참조 카운트가 0이 되는 순간**이다. [Swift 메모리 구조](./swift-memory-model.md)에서 다룬 대로 **시점이 결정적**이다.

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

관련 내용은 [구독 수명 관리 문서](./combine-cancellable-and-store.md)에 정리했다.

### `deinit`에서 주의할 점

**① 다른 객체를 참조하면 안 될 수도 있다**

해제 중인 상태이므로 다른 객체의 상태를 신뢰하기 어렵다.

**② `self`를 escape시키면 안 된다**

```swift
deinit {
    Task { await self.cleanup() }      // ⚠️ 위험 — self가 이미 해제 중
}
```

비동기 작업에 `self`를 넘기면 해제된 객체를 참조하게 된다.

**③ 실행 스레드가 보장되지 않는다**

마지막 참조가 사라진 스레드에서 불린다. UI를 건드리면 안 된다. [MainActor 문서](./main-actor-and-ios-threading.md) 참조.

**④ 상속 관계에서는 자동으로 연쇄된다**

하위 클래스의 `deinit`이 끝나면 상위 클래스의 `deinit`이 자동 호출된다. `super.deinit`을 직접 부를 필요가 없다.

### 정리

```text
[weak self]
  클로저가 self를 약하게 캡처 → 순환 참조를 끊는다
  self가 옵셔널이 되어 해제 후에도 안전하다
  필요한 경우: 클로저가 저장되고, 그 저장 위치를 self가 소유할 때
  불필요한 경우: 즉시 실행 클로저, Task { }, SwiftUI View(struct)

deinit
  인스턴스 해제 직전 호출. class에만 있다
  ARC가 참조 카운트 0이 되는 순간 부른다 (시점이 결정적)
  메모리가 아닌 자원 정리에 쓴다 (파일, 타이머, 옵저버)
  print를 넣어 누수를 확인하는 것이 실용적
  이 코드의 forEach cancel()은 중복 — AnyCancellable이 자동 호출
```

## 학습 체크리스트

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

- [Swift 공식 문서: Deinitialization](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/deinitialization/)
- [Swift 공식 문서: ARC — Strong Reference Cycles for Closures](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting/#Strong-Reference-Cycles-for-Closures)
- [Swift 공식 문서: ARC — Resolving Strong Reference Cycles for Closures](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting/#Resolving-Strong-Reference-Cycles-for-Closures)
- [Swift 공식 문서: ARC — Weak References](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting/#Weak-References)
- [Swift 공식 문서: ARC — Unowned References](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting/#Unowned-References)
- [Swift 공식 문서: Closures — Capturing Values](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/closures/#Capturing-Values)
- [Swift 공식 문서: Expressions — Capture Lists](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/expressions/#Capture-Lists)
- [Apple: AnyCancellable](https://developer.apple.com/documentation/combine/anycancellable)
- [Apple: Task](https://developer.apple.com/documentation/swift/task)
