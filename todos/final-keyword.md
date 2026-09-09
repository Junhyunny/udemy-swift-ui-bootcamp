# `final` 키워드 — 어디에 붙이고 무엇을 막는가

Swift의 상속 구조 전반은 [별도 문서](./swift-type-system-and-inheritance.md)에 정리했다. 이 문서는 **`final`** 하나에 집중한다.

## 질문이 나온 코드

`chapter-65/chapter-65/ContentView.swift`

```swift
@Observable
final class SystemNotificationExample {
    let center = NotificationCenter.default
    var orientation: DTOrientation = .portrait
    // ...
}
```

## 공부할 내용

### 결론 먼저

- **재정의(override)를 막는 키워드**다.
- **클래스 앞**에 붙이면 상속 자체가 불가능해진다.
- **멤버 앞**에 붙이면 그 멤버만 재정의가 막힌다. 프로퍼티, 메서드, 서브스크립트 모두 가능하다.
- `struct`, `enum`에는 붙일 수 없다. **애초에 상속이 없으므로 의미가 없다.**
- 붙이면 **성능상 이점**도 있다.

### 질문 확인: 클래스 앞? 변수 앞?

**둘 다 가능하다.** 붙이는 위치에 따라 범위가 달라진다.

**① 멤버에 붙이기**

> You can prevent a method, property, or subscript from being overridden by marking it as *final*. Do this by writing the `final` modifier before the method, property, or subscript's introducer keyword (such as `final var`, `final func`, `final class func`, and `final subscript`).

```swift
class C {
    final var someVar = 0
    final func someFunction() {
        print("In someFunction")
    }
}
```

하위 클래스가 이것들을 재정의하려 하면 컴파일 에러다.

```swift
class D: C {
    override var someVar: Int { ... }        // ⚠️ 에러
    override func someFunction() { ... }     // ⚠️ 에러
}
```

```
error: instance method overrides a 'final' instance method
```

> Any attempt to override a final method, property, or subscript in a subclass is reported as a compile-time error. Methods, properties, or subscripts that you add to a class in an extension can also be marked as final within the extension's definition.

**② 클래스 전체에 붙이기 — 이 예제**

> You can mark an entire class as final by writing the `final` modifier before the `class` keyword in its class definition (`final class`). **Any attempt to subclass a final class is reported as a compile-time error.**

```swift
final class SystemNotificationExample { ... }
```

```swift
class Sub: SystemNotificationExample { }     // ⚠️ 컴파일 에러
```

**클래스에 `final`을 붙이면 모든 멤버가 자동으로 final이 된다.** 상속 자체가 불가능하니 재정의할 방법도 없다.

### 붙일 수 있는 곳

```swift
final class MyClass { }              // 클래스 전체

class Other {
    final var name = ""              // 저장 프로퍼티
    final var computed: Int { 0 }    // 계산 프로퍼티
    final func doWork() { }          // 인스턴스 메서드
    final class func make() { }      // 타입 메서드
    final subscript(i: Int) -> Int { 0 }   // 서브스크립트
}

extension Other {
    final func helper() { }          // extension 안에서도
}
```

**붙일 수 없는 곳**

```swift
final struct S { }         // ⚠️ 에러 — struct는 상속이 없다
final enum E { }           // ⚠️ 에러
```

에러 메시지가 명확하다.

```
error: 'final' modifier cannot be applied to this declaration
```

[Swift의 타입 체계](./swift-type-system-and-inheritance.md)에서 다룬 대로 상속은 `class`에만 있다. `struct`와 `enum`은 이미 "재정의 불가"이므로 `final`이 중복이다.

`static` 멤버에도 붙일 수 없다. `static`은 이미 재정의가 불가능하기 때문이다. 재정의 가능한 타입 메서드를 만들려면 `class func`을 쓰고, 그것을 막으려면 `final class func`이 된다.

```swift
class A {
    static func a() { }          // 재정의 불가 (이미)
    class func b() { }           // 재정의 가능
    final class func c() { }     // 재정의 불가로 명시
}
```

### 왜 붙이나 — 세 가지 이유

**① 설계 의도를 못 박는다**

"이 클래스는 상속을 전제로 만들지 않았다"를 코드로 표현한다. 상속을 염두에 두지 않은 클래스를 누군가 상속하면, 내부 구현을 바꿀 때 예상치 못한 곳이 깨진다.

**상속은 가장 강한 결합이다.** 하위 클래스는 상위 클래스의 내부 동작에 의존하게 되므로, 상위를 수정하기 어려워진다. `final`은 그 결합을 애초에 차단한다.

**② 성능 — 정적 디스패치**

이것이 실질적 이점이다.

상속 가능한 클래스의 메서드는 **동적 디스패치(dynamic dispatch)** 를 쓴다. 실제로 어느 구현을 호출할지 런타임에 vtable을 조회해 결정한다. 하위 클래스가 재정의했을 수 있기 때문이다.

`final`이면 재정의가 불가능하므로 **컴파일 타임에 호출 대상이 확정**된다. 조회 없이 직접 호출하고, 인라이닝 같은 최적화도 가능해진다.

```text
일반 메서드    호출 → vtable 조회 → 실제 구현으로 점프
final 메서드   호출 → 직접 점프 (인라이닝 가능)
```

체감할 만한 차이는 **호출이 매우 잦은 코드**에서 나타난다. 루프 안에서 수천 번 호출되는 메서드라면 의미가 있고, 버튼 탭 핸들러 하나라면 무시할 수준이다.

**컴파일러가 추론하기도 한다.** 모듈 안에서만 쓰이고 하위 클래스가 없는 것이 확실하면 자동으로 최적화한다(Whole Module Optimization). 다만 `public` 클래스는 외부에서 상속될 수 있으므로 추론이 어렵다. **모듈 경계를 넘는 코드일수록 `final`을 명시하는 가치가 커진다.**

**③ 컴파일 시간 단축**

가능한 재정의를 고려하지 않아도 되므로 타입 체크가 단순해진다. 큰 프로젝트에서 누적되면 차이가 난다.

### 이 예제에서 `final`이 적절한가

```swift
@Observable
final class SystemNotificationExample {
    let center = NotificationCenter.default
    var orientation: DTOrientation = .portrait
    // ...
}
```

**적절하다. 이유가 셋 있다.**

- **상속할 이유가 없다.** 화면 회전을 감지해 상태를 보관하는 단일 목적 클래스다
- **`@Observable`과 함께 쓰는 관용적 형태다.** SwiftUI 뷰 모델은 대부분 `final class`로 만든다. [Observation 문서](./observation-framework-and-observable.md)에서 다룬 대로 관찰 대상은 참조 타입이어야 하고, 상속은 필요 없다
- **성능에 유리하다.** 관찰 대상 프로퍼티는 접근이 잦을 수 있다

**왜 `struct`가 아니라 `class`인가**도 짚어 둘 만하다. `@Observable`은 `class`에만 붙는다. 여러 뷰가 **같은 인스턴스**를 관찰해야 하므로 참조 타입이어야 한다. [struct와 class](./struct-vs-class.md)에서 다룬 구분이다.

### 실무 지침

**기본을 `final`로 두는 편이 낫다.**

Swift는 클래스가 기본적으로 상속 가능하지만, 실제로 상속이 필요한 클래스는 소수다. 상속이 필요해지면 그때 `final`을 지우면 된다. **"열어 두고 나중에 닫기"보다 "닫아 두고 나중에 열기"가 안전하다.**

이미 공개된 클래스에서 `final`을 제거하는 것은 호환성 문제가 없지만, 반대로 `final`을 추가하면 기존 하위 클래스가 깨진다.

**`final`을 쓰지 않는 경우**

- 상속을 전제로 설계한 클래스 (템플릿 메서드 패턴 등)
- UIKit 클래스를 상속받아 만든 커스텀 뷰 — 다시 상속될 수 있다면
- 프레임워크에서 확장점으로 제공하는 클래스

**테스트와의 관계도 알아 둘 만하다.** 상속으로 mock을 만드는 방식을 쓴다면 `final`이 걸림돌이 된다. 하지만 **프로토콜 기반 의존성 주입**이 Swift에서는 더 권장되는 방식이고, 그러면 `final`과 충돌하지 않는다.

```swift
protocol NotificationProviding {
    func observe() async
}

final class SystemNotificationExample: NotificationProviding { ... }
final class MockNotification: NotificationProviding { ... }
```

### 관련 키워드 정리

| 키워드 | 의미 |
| --- | --- |
| `final` | 재정의 금지 |
| `override` | 상위 구현을 재정의 |
| `open` | 모듈 밖에서도 상속·재정의 가능 (클래스 전용) |
| `public` | 모듈 밖에서 사용 가능, **상속은 불가** |
| `static` | 타입 멤버, 재정의 불가 |
| `class func` | 타입 메서드, **재정의 가능** |

`open`과 `public`의 차이가 `final`과 관련이 깊다. [접근 제어 문서](./access-control.md)에서 다뤘다.

```text
open        모듈 밖에서 상속·재정의 가능
public      모듈 밖에서 쓸 수 있지만 상속 불가 (사실상 final에 가깝다)
final       상속·재정의 불가
```

라이브러리를 만들 때 이 구분이 중요해진다. `public class`는 모듈 밖에서 상속할 수 없으므로, 상속을 허용하려면 `open`을 명시해야 한다.

### 정리

```text
final = 재정의(override) 금지

붙이는 곳
  final class     상속 자체가 불가 — 모든 멤버가 자동 final
  final var/func  그 멤버만 재정의 불가
  final subscript, final class func
  extension 안에서도 가능

붙일 수 없는 곳
  struct, enum   — 애초에 상속이 없다
  static 멤버    — 이미 재정의 불가

이점
  ① 설계 의도 명시 — 상속이라는 강한 결합을 차단
  ② 정적 디스패치 — vtable 조회 없이 직접 호출
  ③ 컴파일 시간 단축

권장: 기본을 final로. 필요해지면 그때 연다.
```

## 학습 체크리스트

- [ ] `SystemNotificationExample`을 상속하려 시도해 컴파일 에러를 확인한다.
- [ ] `final`을 지우고 상속이 가능해지는지 확인한다.
- [ ] `final struct S { }`를 시도해 에러 메시지를 읽는다.
- [ ] `final var`, `final func`을 각각 붙여 재정의를 막아 본다.
- [ ] `final` 멤버를 `override`하려 시도해 에러를 확인한다.
- [ ] `class func`과 `final class func`의 재정의 가능 여부를 비교한다.
- [ ] `static func`에 `final`을 붙여 보고 왜 불필요한지 설명한다.
- [ ] `extension` 안에서 `final func`을 선언해 본다.
- [ ] `@Observable`을 `struct`에 붙여 보고 `class`여야 하는 이유를 확인한다.
- [ ] `public class`를 다른 모듈에서 상속하려 해 보고 `open`과의 차이를 확인한다.
- [ ] 프로토콜 기반으로 mock을 만들어 `final`과 테스트가 충돌하지 않는 것을 확인한다.

## 공식 참고 자료

- [Swift 공식 문서: Inheritance — Preventing Overrides](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/inheritance/#Preventing-Overrides)
- [Swift 공식 문서: Inheritance](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/inheritance/)
- [Swift 공식 문서: Declarations — Declaration Modifiers](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/declarations/#Declaration-Modifiers)
- [Swift 공식 문서: Access Control](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/accesscontrol/)
- [Swift 공식 문서: Access Control — Subclassing](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/accesscontrol/#Subclassing)
- [Swift 공식 문서: Properties — Type Properties](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/properties/#Type-Properties)
- [Swift 공식 문서: Methods — Type Methods](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/methods/#Type-Methods)
- [Apple: Observable() 매크로](https://developer.apple.com/documentation/observation/observable())
- [Swift.org: Optimization Tips](https://github.com/swiftlang/swift/blob/main/docs/OptimizationTips.rst)
