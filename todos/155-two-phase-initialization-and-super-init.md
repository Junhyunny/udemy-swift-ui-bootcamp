# `'self' used before 'super.init' call` — Swift의 2단계 초기화

클래스 상속 자체는 [Swift의 타입 체계와 상속 구조](./020-swift-type-system-and-inheritance.md)에서 다룬다. 이 문서는 **상속이 있을 때 이니셜라이저가 지켜야 하는 실행 순서**와, 그 순서를 어겼을 때 나오는 컴파일 오류에 집중한다.

## 질문이 나온 코드

외부 프로젝트 `voip-ios`의 `WebRTCClient.swift`. `NSObject`를 상속한 클래스가 `init` 안에서 자기 자신을 delegate로 등록한다.

```swift
class WebRTCClientImpl: NSObject, WebRTCClient {
    private let peerConnection: RTCPeerConnection
    let events: AsyncStream<WebRTCEvent>
    let factory: RTCPeerConnectionFactory

    init(factory: RTCPeerConnectionFactory = DEFAULT_FACTORY) {
        self.factory = factory
        self.events = AsyncStream { _ in }
        // ... configuration, mediaConstraints 구성 ...
        self.peerConnection = peerConnection

        // super.init()
        self.peerConnection.delegate = self   // ❌ 'self' used before 'super.init' call
    }
}
```

## 공부할 내용

### 결론부터 — 오류는 "순서" 문제다

`self`를 **값으로** 쓰는 순간(`= self`로 넘기기, 인스턴스 메서드 호출, 상속 프로퍼티 접근)에는 **객체가 완성되어 있어야** 한다. 그런데 `super.init()`이 아직 호출되지 않았으므로 상위 클래스(`NSObject`)가 관리하는 부분은 아직 초기화되지 않은 메모리다. 그 미완성 객체의 주소를 `peerConnection`이라는 **다른 객체에게 넘기는** 행위를 컴파일러가 막은 것이다.

### 주석 처리해도 `super.init()`은 사라지지 않는다

가장 먼저 짚어야 할 오해다. 위 코드에서 `super.init()`을 주석 처리했다고 호출이 없어지는 게 아니다.

상위 클래스의 지정 이니셜라이저가 인자를 받지 않으면, 컴파일러가 **이니셜라이저 본문 맨 끝에 `super.init()`을 암묵적으로 삽입한다.** 아래 코드가 그 증거다 — `super.init()`을 한 줄도 쓰지 않았는데 "`super.init()` 시점에 초기화되지 않았다"는 오류가 나온다.

```swift
class E: NSObject {
    var x: Int
    private func makeX() -> Int { 1 }
    override init() {
        self.x = self.makeX()
    }
    // ❌ 'self' used in method call 'makeX' before 'super.init' call
}
```

즉 컴파일러가 **이니셜라이저 본문 맨 끝에** `super.init()`을 끼워 넣는다. 그래서 실제 실행 순서는 이렇게 된다.

```
self.factory = factory
self.events = ...
self.peerConnection = peerConnection
self.peerConnection.delegate = self   ← 여기서 self 사용
[컴파일러가 삽입한 super.init()]       ← 초기화 완료는 그 다음
```

`self` 사용이 `super.init()`보다 **앞선다.** 오류 메시지 그대로다.

### 2단계 초기화(Two-Phase Initialization)

Swift가 이런 규칙을 두는 이유는 초기화를 두 단계로 나누기 때문이다.

> "Class initialization in Swift is a two-phase process. In the first phase, each stored property is assigned an initial value by the class that introduced it. Once the initial state for every stored property has been determined, the second phase begins, and each class is given the opportunity to customize its stored properties further before the new instance is considered ready for use."

| 단계 | 하는 일 | 방향 |
| --- | --- | --- |
| **1단계** | 각 클래스가 **자기가 선언한** 저장 프로퍼티에 초기값을 넣고 위로 위임(`super.init()`) | 하위 → 상위 |
| **2단계** | 체인이 끝나고 되돌아오면서 값 수정, 메서드 호출, `self` 사용 | 상위 → 하위 |

`super.init()` 호출은 **1단계의 끝이자 2단계의 시작점**이다. 그 줄을 지나기 전은 "아직 조립 중", 지난 후는 "사용 가능한 객체"다.

Objective-C와의 결정적 차이도 여기 있다.

> "Swift's two-phase initialization process is similar to initialization in Objective-C. The main difference is during phase 1, Objective-C assigns zero or null values to every property. Swift's initialization flow is more flexible in that it lets you set custom initial values, and can cope with types for which 0 or nil isn't a valid default value."

Objective-C는 전부 0/nil로 채우고 시작하니 미완성 객체를 만져도 "일단" 돌아간다. Swift는 옵셔널이 아닌 프로퍼티에 0이나 nil이 들어갈 수 없으므로, 미완성 상태 접근을 **컴파일 타임에** 막아야 한다.

### 컴파일러가 강제하는 네 가지 안전 점검

Swift 공식 가이드의 safety check 네 가지다. 이번 오류는 4번에 해당한다.

1. **지정 이니셜라이저는 상위로 위임하기 전에 자기 클래스가 선언한 모든 프로퍼티를 초기화해야 한다.**
2. **상속받은 프로퍼티에 값을 대입하려면 `super.init()`을 먼저 호출해야 한다.** 안 그러면 상위 이니셜라이저가 내가 쓴 값을 덮어쓴다.
3. **편의(convenience) 이니셜라이저는 다른 이니셜라이저에 위임한 뒤에야 프로퍼티에 대입할 수 있다.**
4. **1단계가 끝나기 전에는 인스턴스 메서드 호출, 인스턴스 프로퍼티 읽기, `self`를 값으로 참조하는 것 모두 불가능하다.**

> "An initializer cannot call any instance methods, read the values of any instance properties, or refer to `self` as a value until after the first phase of initialization is complete."

이 기준으로 문제의 한 줄을 다시 보면, 위반은 **맨 끝의 `self` 하나뿐이다.**

```swift
self.peerConnection.delegate = self
//   ^^^^^^^^^^^^^^ 이미 채운 내 프로퍼티라 읽기 OK   ^^^^ ❌ self를 값으로 넘김
```

그 위의 `self.factory = factory`, `self.events = ...`, `self.peerConnection = peerConnection`도 **모두 정상이다.** 자기가 선언한 저장 프로퍼티에 값을 **쓰는** 행위는 1단계의 본업이다.

> **책의 규칙과 컴파일러의 실제 판정은 다르다.** 위 safety check 4번은 "인스턴스 프로퍼티 읽기"까지 금지한다고 쓰여 있지만, 실제 컴파일러(Apple Swift 6.4로 확인)는 더 세밀하다. **자기가 선언했고 이미 값을 채운** 프로퍼티는 `super.init()` 전에도 읽을 수 있다. 정의 초기화(definite initialization) 분석이 "이 시점에 이 프로퍼티는 확실히 값이 있다"를 추적하기 때문이다. 아직 안 채운 프로퍼티를 읽으면 다른 메시지가 나온다 — `variable 'self.x' used before being initialized`. 1단계에서 진짜로 막히는 것은 **상속 멤버 접근, 인스턴스 메서드 호출, `self`를 값으로 넘기기** 세 가지다. 선언 방식별 초기화 의무와 오류 메시지 대조표는 [객체 생성 라이프 사이클과 이니셜라이저](./156-object-lifecycle-and-initializers.md)에 정리했다.

### 왜 이렇게까지 막나 — self 유출(escape) 문제

`peerConnection.delegate = self`는 단순한 대입이 아니라 **미완성 객체의 참조를 외부 객체에게 넘기는** 행위다. `RTCPeerConnection`은 그 순간부터 언제든 delegate 메서드를 호출할 수 있고, 그 메서드는 아직 초기화되지 않은 상태를 읽게 된다. WebRTC 같은 라이브러리는 내부 스레드에서 콜백을 던지므로 실제로 일어날 수 있는 시나리오다.

`NSObject` 상속이면 이유가 하나 더 붙는다. `NSObject.init`은 Objective-C 런타임이 객체를 정상 객체로 등록하는 지점이다. 그 전의 `self`는 KVO, 셀렉터 전달, `respondsToSelector:` 같은 런타임 기능을 안전하게 쓸 수 없다.

JVM 언어와 비교하면 차이가 선명하다. Java도 `super()`가 생성자의 첫 문장이어야 하지만, `this`를 생성자 안에서 외부에 넘기는 것 자체는 막지 않는다(이른바 *this escape*는 오랫동안 알려진 버그 패턴이고, 최근 javac는 `this-escape` 린트 경고로 알려준다). Swift는 같은 문제를 **경고가 아니라 컴파일 오류로** 처리한다. [Swift의 메모리 구조](./022-swift-memory-model.md)에서 본 "초기화되지 않은 메모리를 만들지 않는다"는 원칙의 연장선이다.

### 해결 — `super.init()`을 경계선으로 삼는다

```swift
init(factory: RTCPeerConnectionFactory = DEFAULT_FACTORY) {
    // ── 1단계: 내가 선언한 저장 프로퍼티를 전부 채운다 ──
    self.factory = factory
    self.events = AsyncStream { _ in }

    let configuration = RTCConfiguration()
    // ... 설정 ...

    guard let peerConnection = factory.peerConnection(
        with: configuration, constraints: mediaConstraints, delegate: nil
    ) else {
        fatalError("failed to create RTCPeerConnection")
    }
    self.peerConnection = peerConnection

    super.init()   // ── 경계선: 여기부터 self는 완성된 객체 ──

    // ── 2단계: self를 써도 되는 구간 ──
    self.peerConnection.delegate = self
}
```

`super.init()` 한 줄을 **주석 해제하고 위치를 맞추는 것**이 수정의 전부다. `guard ... else { fatalError }`로 조기 탈출하는 부분은 `super.init()` 이전이어도 문제없다. `fatalError()`는 `Never`를 반환하므로 초기화가 완료될 경로가 아니기 때문이다([`guard` 키워드](./158-conditional-statements-complete-guide.md)).

### `self`를 나중에 써야 할 때의 선택지

`super.init()` 뒤로 옮기는 것이 가장 단순하지만, 구조상 그게 안 되는 경우도 있다.

| 방법 | 언제 | 대가 |
| --- | --- | --- |
| `super.init()` 이후로 이동 | 대부분의 경우 | 없음. 우선 고려한다 |
| `lazy var` | `self`에 의존하는 프로퍼티를 늦게 만들고 싶을 때 | 첫 접근 시점에 생성, `let` 불가 |
| 암시적 언래핑 옵셔널(`T!`) | 순환 의존이라 1단계에 값을 못 정할 때 | 런타임 크래시 위험([암시적 언래핑 옵셔널](./005-implicitly-unwrapped-optional.md)) |
| 별도 `setup()` 메서드 / 정적 팩토리 | delegate 연결을 초기화와 분리하고 싶을 때 | 호출을 잊으면 미완성 객체가 돌아다님 |

`struct`에는 이 규칙이 아예 적용되지 않는다. 상속이 없어 위임할 상위가 없으므로 모든 저장 프로퍼티만 채우면 곧바로 `self`를 쓸 수 있다. [`struct`와 `class`](./019-struct-vs-class.md)에서 본 "가능하면 `struct`" 권고가 초기화 복잡도 면에서도 유효한 이유다.

### 덤 — 이 예제에 남아 있는 두 번째 문제

컴파일 오류와 별개로 `self.events = AsyncStream { _ in }`은 **continuation을 버리고 있다.** 클로저가 받는 인자가 continuation인데 `_`로 무시하므로, 이 스트림은 값을 하나도 내보내지 못하고 구독자는 영원히 대기한다. delegate 콜백을 스트림으로 흘리려면 continuation을 프로퍼티로 붙잡아야 한다.

```swift
private let continuation: AsyncStream<WebRTCEvent>.Continuation

init(...) {
    var continuation: AsyncStream<WebRTCEvent>.Continuation!
    self.events = AsyncStream { continuation = $0 }
    self.continuation = continuation
    // ...
    super.init()
    self.peerConnection.delegate = self
}
```

`AsyncStream` 자체는 [AsyncStream](./154-async-stream.md)에서 다룬다. 여기서 겹쳐 보면, 지역 변수 `continuation`을 거쳐 우회하는 이 패턴도 결국 **1단계에서는 self를 못 쓴다**는 같은 제약에서 나온 관용구다.

## 학습 체크리스트

- [ ] `super.init()`을 주석 처리한 상태에서 오류 메시지의 위치(어느 줄을 가리키는지)를 확인한다.
- [ ] `self.peerConnection.delegate = self`를 `super.init()` 앞뒤로 옮겨 보며 오류가 사라지는 지점을 확인한다.
- [ ] 저장 프로퍼티에 **쓰기**는 되고 **읽기**는 안 되는 것을 `super.init()` 앞에서 `print(self.factory)`로 직접 확인한다.
- [ ] 상위 클래스에 저장 프로퍼티를 하나 둔 2단계 상속 클래스를 만들고, safety check 2번(상속 프로퍼티는 `super.init()` 이후에 대입)을 위반해 본다.
- [ ] 같은 클래스를 `NSObject` 상속 없이 순수 Swift 클래스로 바꿔도 동일한 오류가 나는지 확인한다.
- [ ] `struct`로 같은 구조를 만들어 `self` 사용 제약이 없는 것을 비교한다.
- [ ] `convenience init`을 추가해 safety check 3번(위임 전 대입 금지)을 위반해 본다.
- [ ] `lazy var`와 `T!` 두 가지 우회책을 각각 적용해 보고 어떤 대가를 치르는지 정리한다.
- [ ] `AsyncStream`의 continuation을 프로퍼티로 잡아 delegate 콜백이 `events`로 흘러나오는지 확인한다.

## 참고 자료

- [The Swift Programming Language: Initialization — Two-Phase Initialization](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/initialization/#Two-Phase-Initialization)
- [The Swift Programming Language: Initialization — Class Inheritance and Initialization](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/initialization/#Class-Inheritance-and-Initialization)
- [The Swift Programming Language: Initialization — Initializer Delegation for Class Types](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/initialization/#Initializer-Delegation-for-Class-Types)
- [The Swift Programming Language: Inheritance](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/inheritance/)
- [The Swift Programming Language: Automatic Reference Counting](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting/)
- [Apple: NSObject](https://developer.apple.com/documentation/objectivec/nsobject)
- [Apple: AsyncStream](https://developer.apple.com/documentation/swift/asyncstream)
- [Apple: AsyncStream.Continuation](https://developer.apple.com/documentation/swift/asyncstream/continuation)
