# 객체 생성 라이프 사이클과 이니셜라이저 — 선언 방식이 초기화 시점을 정한다

[`'self' used before 'super.init' call`](./155-two-phase-initialization-and-super-init.md)에서 2단계 초기화의 **순서**를 봤다. 이 문서는 그 위에 얹히는 실전 규칙을 다룬다. **저장 프로퍼티를 어떻게 선언했느냐(`let`/`var`/옵셔널/기본값/`lazy`)가 "언제 채워야 하는가"를 결정한다.**

이 문서의 모든 판정은 **Apple Swift 6.4**로 직접 컴파일해 확인했다.

## 질문이 나온 코드

외부 프로젝트 `voip-ios`의 `WebRTCClient.swift`. 155의 오류를 피하려고 생성 로직을 헬퍼 메서드로 빼고 `let`을 `var`로 바꿨는데, 이번엔 다른 오류가 났다.

```swift
class WebRTCClientImpl: NSObject, WebRTCClient {
    private var peerConnection: RTCPeerConnection   // let → var 로 바꿔봄

    private func makePeerConnection(factory: RTCPeerConnectionFactory)
        -> RTCPeerConnection { /* ... */ }           // 인스턴스 메서드

    init(factory: RTCPeerConnectionFactory = DEFAULT_FACTORY) {
        self.factory = factory
        self.events = AsyncStream { _ in }

        super.init()   // ❌ Property 'self.peerConnection' not initialized at super.init call
        self.peerConnection = self.makePeerConnection(factory: factory)
        self.peerConnection.delegate = self
    }
}
```

## 공부할 내용

### 결론부터 — `super.init()`은 "전부 채웠음"을 확인하는 관문이다

오류 메시지가 **`super.init()` 줄을 가리키는 것**이 핵심 단서다. 컴파일러는 "네가 `peerConnection`을 나중에 채우려는 건 알겠는데, `super.init()`을 지나는 순간 이미 채워져 있었어야 한다"고 말하는 것이다.

155에서 본 safety check 1번이 그대로다.

> "A designated initializer must ensure that all of the properties introduced by its class are initialized before it delegates up to a superclass initializer."

그래서 **"`super.init()` 뒤로 옮기면 되겠지"라는 회피는 통하지 않는다.** 2단계로 미룰 수 있는 것은 *이미 값이 있는 프로퍼티를 바꾸는 일*이지, *처음 채우는 일*이 아니다.

### 왜 `var`로 바꿔도 안 되는가

`let` → `var` 변경이 실패한 이유가 여기 있다. `let`/`var`는 **몇 번 쓸 수 있는가**를 정하지 **언제 처음 채우는가**를 바꾸지 못한다.

| 선언 | 1단계에 반드시 채워야 하나 | 2단계에서 다시 대입 | 확인된 오류 |
| --- | --- | --- | --- |
| `let x: T` | **예** | 불가 | `immutable value 'self.x' may only be initialized once` |
| `var x: T` | **예** | 가능 | — |
| `var x: T = 기본값` | 아니오(선언부에서 이미 채워짐) | 가능 | — |
| `var x: T?` | 아니오(**자동 `nil`**) | 가능 | — |
| `var x: T!` | 아니오(**자동 `nil`**) | 가능 | — |
| `let x: T?` | **예** ← 함정 | 불가 | `property 'self.x' not initialized at super.init call` |
| `lazy var x` | 아니오 | — | 1단계 접근 시 `'self' used in property access ...` |

주목할 두 줄이 있다.

- **`let x: T?`는 자동 `nil`이 되지 않는다.** "옵셔널은 자동으로 nil"이라는 문장은 **`var`에만** 해당한다. `let`은 한 번만 쓸 수 있으니 자동 `nil`을 넣어버리면 영원히 `nil`로 굳는다. 그래서 컴파일러는 자동으로 채우지 않고 "직접 채워라"고 요구한다. `self.x = nil`이라고 명시하면 통과한다.
- **`var x: T!`(IUO)가 흔한 우회로인 이유가 이것이다.** 자동 `nil` 덕분에 1단계를 건너뛰고, 2단계에서 `self`를 쓰는 코드로 채울 수 있다. 대가는 런타임 크래시 위험이다([암시적 언래핑 옵셔널](./005-implicitly-unwrapped-optional.md)).

### 진짜 원인 — 인스턴스 메서드는 1단계에서 못 쓴다

`var`로 바꿔도 안 되는 근본 이유는 `makePeerConnection`이 **인스턴스 메서드**라는 데 있다. 인스턴스 메서드 호출은 완성된 `self`를 요구하므로 2단계에서만 가능하다. 그런데 `peerConnection`은 1단계에 채워야 한다. **닭과 달걀 문제**다.

```
1단계에 채워야 함  ──┐
                    ├── 서로 모순
2단계에만 호출 가능 ──┘
```

컴파일러는 이 모순을 `super.init()` 지점의 오류로 보고한다. 155의 오류와 이번 오류는 **같은 2단계 모델의 앞면과 뒷면**이다.

| | 155의 오류 | 이번 오류 |
| --- | --- | --- |
| 메시지 | `'self' used before 'super.init' call` | `Property 'self.x' not initialized at super.init call` |
| 위반 | safety check 4 (너무 일찍 `self` 사용) | safety check 1 (너무 늦게 프로퍼티 초기화) |
| 뜻 | "완성 전에 쓰지 마라" | "관문 전에 다 채워라" |

### 해결 — 헬퍼를 `static`으로 올린다

`self`가 필요 없는 로직이면 타입 메서드로 만들면 된다. 타입 메서드는 인스턴스와 무관하므로 **1단계에서 호출할 수 있다.**

```swift
private static func makePeerConnection(factory: RTCPeerConnectionFactory)
    -> RTCPeerConnection
{
    let configuration = RTCConfiguration()
    // ... 설정 ...
    guard let peerConnection = factory.peerConnection(
        with: configuration, constraints: mediaConstraints, delegate: nil
    ) else {
        fatalError("failed to create RTCPeerConnection")
    }
    return peerConnection
}

init(factory: RTCPeerConnectionFactory = DEFAULT_FACTORY) {
    // ── 1단계 ──
    self.factory = factory
    self.events = AsyncStream { _ in }
    self.peerConnection = WebRTCClientImpl.makePeerConnection(factory: factory)

    super.init()

    // ── 2단계 ──
    self.peerConnection.delegate = self
}
```

`WebRTCClientImpl.makePeerConnection(...)` 대신 `Self.makePeerConnection(...)`도 1단계에서 정상 동작한다(확인함). 이 방식이면 `peerConnection`을 다시 **`let`으로 되돌릴 수 있다.** 한 번 정하고 바꾸지 않는 값이므로 `let`이 의도에 맞다.

대안으로 IUO를 쓸 수도 있다. 둘 중에는 `static` 쪽이 낫다.

| 방법 | 장점 | 단점 |
| --- | --- | --- |
| `static func` + `let` (권장) | 불변, 런타임 위험 없음, 의존성이 인자로 드러남 | `self` 쓰는 로직은 못 옮김 |
| `var peerConnection: RTCPeerConnection!` | 인스턴스 메서드 그대로 사용 | 실수로 `nil` 접근 시 크래시, 불변성 상실 |

### 객체 생성 라이프 사이클 전체 그림

지금까지의 규칙이 어디에 놓이는지 정리하면 이렇다.

```
1. 메모리 할당 (alloc)        — 런타임이 인스턴스 크기만큼 확보. 아직 쓰레기 값
2. 초기화 1단계               — 하위 → 상위, 각자 선언한 저장 프로퍼티를 채움
   └ super.init() ───────────  관문: 여기서 모든 저장 프로퍼티가 값을 가져야 함
3. 초기화 2단계               — 상위 → 하위, self 사용 가능 (메서드 호출, delegate 등록)
4. 사용                       — ARC가 참조 카운트 관리
5. deinit                     — 하위 → 상위 순으로 자동 호출. 옵저버 해제, 리소스 정리
6. 메모리 해제 (dealloc)
```

1~3단계가 이 문서의 범위고, 4~6단계는 [`[weak self]`와 `deinit`](./023-weak-self-and-deinit.md)이 다룬다. `deinit`이 **2단계의 역순**(하위 → 상위)이라는 점이 대칭적이라 같이 외워두면 좋다.

Objective-C의 `[[Foo alloc] init]`이 1과 2~3을 한 줄에 쓴 것이고, Swift의 `Foo()`는 같은 일을 문법으로 감쌌다. 차이는 155에서 본 대로 **ObjC는 모두 0/nil로 채우고 시작하지만 Swift는 개발자가 값을 정해야 한다**는 것이다.

### 이니셜라이저의 종류

| 종류 | 문법 | 역할 |
| --- | --- | --- |
| 지정(designated) | `init(...)` | 모든 저장 프로퍼티를 책임지고 `super.init()` 호출. 클래스의 주 통로 |
| 편의(convenience) | `convenience init(...)` | 같은 클래스의 다른 이니셜라이저에 **가로로** 위임(`self.init`). 프로퍼티를 직접 못 채움 |
| 필수(required) | `required init(...)` | 모든 하위 클래스가 반드시 구현 |
| 실패 가능(failable) | `init?(...)` | 실패 시 `nil` 반환. 검증이 필요한 생성에 사용 |

위임 방향 규칙은 셋이다.

> "Rule 1: A designated initializer must call a designated initializer from its immediate superclass.
> Rule 2: A convenience initializer must call another initializer from the *same* class.
> Rule 3: A convenience initializer must ultimately call a designated initializer."

**지정은 위로, 편의는 옆으로**로 기억하면 된다. 편의 이니셜라이저가 위임 전에 프로퍼티를 건드리면 safety check 3번 위반이고, 메시지가 다르다 — `'self' used before 'self.init' call or assignment to 'self'`.

UIKit을 쓰면 `required init?(coder: NSCoder)`를 Xcode가 자동으로 넣어주는 걸 보게 되는데, `UIView`/`UIViewController`가 `NSCoding`을 통해 이 이니셜라이저를 `required`로 요구하기 때문이다.

### 오류 메시지 대조표 (Swift 6.4 실측)

각 메시지가 **어느 규칙**을 가리키는지 알면 진단이 빨라진다.

| 코드 | 메시지 | 원인 |
| --- | --- | --- |
| `super.init()` 시점에 안 채운 프로퍼티가 있음 | `property 'self.x' not initialized at super.init call` | safety check 1 |
| `let`을 `super.init()` 뒤에 대입 | `immutable value 'self.x' may only be initialized once` (+ 위 메시지 동반) | `let`은 1단계 전용 |
| 1단계에서 상속 프로퍼티 접근 | `'self' used in property access 'inherited' before 'super.init' call` | safety check 2 |
| 1단계에서 인스턴스 메서드 호출 | `'self' used in method call 'helper' before 'super.init' call` | safety check 4 |
| 1단계에서 `lazy var` 접근 | `'self' used in property access 'z' before 'super.init' call` | `lazy`는 `self` 필요 |
| 1단계에서 `self`를 값으로 전달 | `'self' used before 'super.init' call` | safety check 4 |
| 아직 안 채운 자기 프로퍼티를 읽음 | `variable 'self.x' used before being initialized` | 정의 초기화 위반 |
| 편의 이니셜라이저가 위임 전에 대입 | `'self' used before 'self.init' call or assignment to 'self'` | safety check 3 |

반대로 **1단계에서 허용되는 것**도 확인해 두면 헷갈리지 않는다.

- 자기가 선언한 저장 프로퍼티에 **쓰기**
- 자기가 선언했고 **이미 채운** 프로퍼티 **읽기** (책의 서술보다 컴파일러가 관대하다)
- `static`/`Self.` 타입 메서드·타입 프로퍼티 호출
- 지역 변수, 인자, 전역 함수 사용
- `guard ... else { fatalError() }` 같은 조기 탈출

### 직접 확인해 보기

Xcode 없이도 검증할 수 있다. 다만 **`swiftc -typecheck`로는 이 오류가 안 잡힌다.** 초기화 검사는 타입 검사가 아니라 SIL 단계의 정의 초기화(definite initialization) 패스에서 수행되기 때문이다.

```sh
swiftc -emit-sil sample.swift -o /dev/null   # 초기화 오류까지 나온다
swiftc -typecheck sample.swift               # 초기화 오류는 통과해 버린다
```

## 학습 체크리스트

- [ ] `swiftc -emit-sil`과 `swiftc -typecheck`로 같은 파일을 검사해 초기화 오류가 어디서 잡히는지 비교한다.
- [ ] `let x: Int?`만 선언한 클래스를 컴파일해 **옵셔널 `let`은 자동 `nil`이 아니다**를 확인한다.
- [ ] 같은 프로퍼티를 `var x: Int?`로 바꿔 오류가 사라지는 것을 확인한다.
- [ ] `let`을 `super.init()` 뒤에 대입해 두 개의 오류가 함께 나오는 것을 확인한다.
- [ ] 헬퍼를 인스턴스 메서드 → `static` 메서드로 바꿔 1단계 호출이 가능해지는 것을 확인한다.
- [ ] `Self.helper()`와 `TypeName.helper()`가 1단계에서 모두 동작하는지 확인한다.
- [ ] `lazy var`를 `super.init()` 앞에서 접근해 어떤 메시지가 나오는지 본다.
- [ ] 상위 클래스에 `var`를 두고 `super.init()` 앞에서 대입해 safety check 2번을 재현한다.
- [ ] `convenience init`에서 `self.init` 전에 프로퍼티를 대입해 메시지가 다른 것을 확인한다.
- [ ] 2단계 상속 클래스에 `deinit`을 모두 넣고 호출 순서가 하위 → 상위인지 출력으로 확인한다.
- [ ] `WebRTCClientImpl`을 `static func` 방식으로 고친 뒤 `peerConnection`을 `let`으로 되돌린다.

## 참고 자료

- [The Swift Programming Language: Initialization](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/initialization/)
- [The Swift Programming Language: Initialization — Two-Phase Initialization](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/initialization/#Two-Phase-Initialization)
- [The Swift Programming Language: Initialization — Initializer Delegation for Class Types](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/initialization/#Initializer-Delegation-for-Class-Types)
- [The Swift Programming Language: Initialization — Failable Initializers](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/initialization/#Failable-Initializers)
- [The Swift Programming Language: Initialization — Required Initializers](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/initialization/#Required-Initializers)
- [The Swift Programming Language: Deinitialization](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/deinitialization/)
- [The Swift Programming Language: Properties — Lazy Stored Properties](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/properties/#Lazy-Stored-Properties)
- [The Swift Programming Language: Methods — Type Methods](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/methods/#Type-Methods)
- [Apple: NSCoding](https://developer.apple.com/documentation/foundation/nscoding)
- [Swift Compiler: Definite Initialization (DI) — swift/lib/SILOptimizer/Mandatory](https://github.com/swiftlang/swift/blob/main/lib/SILOptimizer/Mandatory/DefiniteInitialization.cpp)
