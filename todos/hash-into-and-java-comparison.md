# `hash(into:)`는 무엇인가 — Java의 `equals()`·`hashCode()`와 비교

해시 충돌 걱정과 `id`의 신원 문제는 [별도 문서](./hashable-id-and-collisions.md)에, `enum`의 자동 합성 규칙은 [여기](./enum-hashable-conformance.md)에 정리했다. 이 문서는 **`hash(into:)` 함수 자체**를 다룬다.

## 질문이 나온 코드

`chapter-60/chapter-60/ContentView.swift`

```swift
struct DevTechieCourse: Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String

    // func hash(into hasher: inout Hasher) {
    //     hasher.combine(id)
    // }
}
```

## 공부할 내용

### 결론 먼저

- `hash(into:)`는 **`Hashable` 프로토콜의 요구사항**이다. "재정의(override)"가 아니라 **요구사항 구현**이다.
- 조건이 맞으면 컴파일러가 **자동으로 만들어 준다.** 그래서 주석 처리해도 동작한다.
- Java의 `hashCode()`와 **역할은 같지만 방식이 다르다.** Java는 정수를 직접 반환하고, Swift는 **재료를 `Hasher`에 넣어 준다.**
- `equals()`에 대응하는 것은 `hash(into:)`가 아니라 **`Equatable`의 `==`** 다.

### `Hashable`의 구조

```swift
protocol Hashable : Equatable {
    func hash(into hasher: inout Hasher)
}
```

두 가지를 눈여겨봐야 한다.

**① `Equatable`을 상속한다.** 따라서 `Hashable`을 채택하면 `==`도 함께 요구된다.

> The `Hashable` protocol inherits from the `Equatable` protocol, so you must also satisfy that protocol's requirements.

**② 요구사항은 `hash(into:)` 하나뿐이다.** `hashValue`는 deprecated다.

### "재정의할 수 있는 함수인가" — 용어부터

Swift에서는 구분이 필요하다.

```swift
struct A: Hashable {
    func hash(into hasher: inout Hasher) { ... }   // 프로토콜 요구사항 구현
}

class B: SuperClass {
    override func draw() { ... }                    // 상속받은 메서드 재정의
}
```

`hash(into:)`에는 `override`를 붙이지 않는다. `struct`는 상속이 없으므로 애초에 `override`가 불가능하다. [Swift의 타입 체계와 상속](./swift-type-system-and-inheritance.md)에서 다룬 구분이다.

정확히 말하면 **"컴파일러가 자동 합성해 주는 구현을 내가 직접 작성해 대체한다"** 가 맞다. Apple 문서의 표현은 이렇다.

> **To customize your type's `Hashable` conformance**, to adopt `Hashable` in a type that doesn't meet the criteria listed above, or to extend an existing type to conform to `Hashable`, **implement the `hash(into:)` method** in your custom type.

### 자동 합성 조건 — 그래서 주석 처리해도 되는 이유

> The compiler automatically synthesizes your custom type's `Hashable` and requirements when you declare `Hashable` conformance in the type's original declaration and your type meets these criteria:
> - For a struct, **all its stored properties must conform to `Hashable`**.
> - For an enum, all its associated values must conform to `Hashable`. (An enum without associated values has `Hashable` conformance even without the declaration.)

`DevTechieCourse`의 저장 프로퍼티는 `UUID`와 `String`이고 둘 다 `Hashable`이다. 그래서 자동 합성이 되고, 주석 처리된 `hash(into:)` 없이도 컴파일된다.

**자동 합성이 만드는 것은 "모든 저장 프로퍼티를 사용하는" 구현**이다. 개념적으로 이렇다.

```swift
// 컴파일러가 만들어 주는 것
func hash(into hasher: inout Hasher) {
    hasher.combine(id)
    hasher.combine(name)
}

static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id && lhs.name == rhs.name
}
```

### 직접 구현하면 무엇이 달라지나

주석을 풀면 이렇게 된다.

```swift
func hash(into hasher: inout Hasher) {
    hasher.combine(id)      // id만 사용
}
```

**`name`이 해시 계산에서 빠진다.** `id`가 같으면 `name`이 달라도 같은 해시 버킷에 들어간다.

여기서 **중요한 함정**이 있다. `hash(into:)`만 고치면 `==`는 여전히 자동 합성된 것(`id`와 `name` 둘 다 비교)이 남는다. 그러면 규약이 깨진다.

Apple이 이 규약을 명시한다.

> Hashing a value means feeding its essential components into a hash function, represented by the `Hasher` type. **Essential components are those that contribute to the type's implementation of `Equatable`. Two instances that are equal must feed the same values to `Hasher` in `hash(into:)`, in the same order.**

핵심 규약은 **"같으면(`==`) 해시도 같아야 한다"** 이고, 그러려면 **`==`가 보는 프로퍼티와 `hash(into:)`가 넣는 프로퍼티가 일치해야 한다.**

지금 상태는 그 반대 방향이라 당장 크래시는 없다. `id`가 같고 `name`이 다른 두 인스턴스는 `==`로 다르지만 해시는 같다 — 이건 **허용되는 충돌**이다. 하지만 의도가 "id만이 신원"이라면 `==`도 함께 고쳐야 한다.

Apple 문서의 예제가 정석을 보여 준다.

```swift
extension GridPoint: Hashable {
    static func == (lhs: GridPoint, rhs: GridPoint) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}
```

> The `hash(into:)` method in this example feeds the grid point's `x` and `y` properties into the provided hasher. **These properties are the same ones used to test for equality in the `==` operator function.**

그래서 `id`만 신원으로 삼으려면 이렇게 짝을 맞춘다.

```swift
struct DevTechieCourse: Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id                // id만 비교
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)              // id만 넣기
    }
}
```

Apple도 이 짝맞춤을 권한다.

> To ensure that your type meets the semantic requirements of the `Hashable` and `Equatable` protocols, **it's a good idea to also customize your type's `Equatable` conformance to match**.

### `Hasher`는 어떻게 동작하나

`inout Hasher`라는 시그니처가 방식을 말해 준다. **해시 값을 만들어 반환하는 것이 아니라, 재료를 넣어 주는 것**이다.

> `Hasher` can be used to map an arbitrary sequence of bytes to an integer hash value. You can feed data to the hasher using a series of calls to mutating `combine` methods. When you've finished feeding the hasher, the hash value can be retrieved by calling `finalize()`:

```swift
var hasher = Hasher()
hasher.combine(23)
hasher.combine("Hello")
let hashValue = hasher.finalize()
```

**`finalize()`는 표준 라이브러리가 호출한다.** 내 `hash(into:)`에서는 `combine`만 부르고 끝낸다. `finalize()`를 직접 부르면 안 된다.

**순서가 결과에 영향을 준다.** `combine(x)` 다음 `combine(y)`와, 반대 순서는 다른 해시를 만든다. 그래서 규약이 "같은 값을 **같은 순서로**" 넣으라고 요구한다.

**해시 값은 실행마다 달라진다.**

> **Do not save or otherwise reuse hash values across executions of your program.** `Hasher` is usually randomly seeded, which means it will return different values on every new execution of your program. The hash algorithm implemented by `Hasher` may itself change between any two versions of the standard library.

무작위 시드를 쓰기 때문이다. 이건 해시 충돌 공격(HashDoS)을 막는 보안 조치이기도 하다. [해시 충돌 문서](./hashable-id-and-collisions.md)에서 다룬 "해시 값을 저장하면 안 된다"가 이 이유다.

### Java의 `equals()`·`hashCode()`와 비교

**역할은 대응되지만 방식이 다르다.**

| | Java | Swift |
| --- | --- | --- |
| 동등성 | `boolean equals(Object o)` | **`static func ==` (`Equatable`)** |
| 해시 | `int hashCode()` | **`func hash(into:)` (`Hashable`)** |
| 반환 | **`int`를 직접 반환** | **반환 없음. `Hasher`에 넣어 준다** |
| 정의 위치 | `Object`에 있음 → **모든 클래스가 상속** | 프로토콜 채택 시에만 |
| 자동 생성 | 없음 (IDE·Lombok·record에 의존) | **컴파일러가 합성** |
| 실행 간 안정성 | 구현에 따라 안정적일 수 있음 | **매 실행마다 달라진다** |
| 타입 안전성 | `Object` 파라미터 → 캐스팅·`instanceof` 필요 | 같은 타입만 비교 |
| `null` 처리 | 직접 처리 필요 | 옵셔널로 타입 수준 구분 |

**① 가장 큰 차이 — 해시 값을 직접 만들지 않는다**

```java
// Java
@Override
public int hashCode() {
    return Objects.hash(id, name);      // 정수를 직접 계산해 반환
}
```

```swift
// Swift
func hash(into hasher: inout Hasher) {
    hasher.combine(id)                   // 재료만 제공
    hasher.combine(name)
}
```

Swift 방식의 장점이 있다. **해시 알고리즘을 표준 라이브러리가 통제**하므로, 개발자가 잘못된 해시 함수를 짜서 성능을 망칠 여지가 없다. Java에서 `return 1;`처럼 상수를 돌려주는 실수가 Swift에서는 구조적으로 불가능하다.

**② `Object` 상속이 아니라 프로토콜 채택이다**

Java의 모든 객체는 `hashCode()`를 갖는다. 기본 구현은 객체의 신원(identity)에 기반하므로, `equals()`를 오버라이드하면서 `hashCode()`를 빠뜨리면 `HashMap`이 오동작한다. 유명한 함정이다.

Swift는 `Hashable`을 채택하지 않으면 `Set`이나 딕셔너리 키로 쓸 수 없다. **컴파일 단계에서 막힌다.** 그리고 채택하면 둘 다 자동 합성되므로 "하나만 구현하는" 실수가 잘 나오지 않는다.

**③ 규약은 같다**

두 언어의 핵심 계약은 동일하다.

```text
a == b  이면  hash(a) == hash(b)     (필수)
hash(a) == hash(b)  이면  a == b     (보장되지 않음 — 충돌 가능)
```

Java의 `hashCode()` 계약과 Swift의 "essential components" 규약이 같은 내용이다.

**④ Java의 `record`와 비슷해졌다**

Java 16의 `record`는 `equals()`, `hashCode()`, `toString()`을 자동 생성한다.

```java
record Course(UUID id, String name) { }
```

```swift
struct Course: Hashable {
    var id: UUID
    var name: String
}
```

이 둘이 가장 가까운 대응이다. Swift는 처음부터 `struct`에 이 기능을 넣었다.

### 언제 직접 구현하나

**자동 합성으로 충분한 경우가 대부분이다.** 직접 쓸 이유는 이렇다.

**① 신원을 특정 프로퍼티로 한정할 때**

`id`만이 신원이고 나머지는 부수 데이터일 때. 서버에서 받은 모델이 대표적이다.

```swift
struct User: Hashable {
    let id: Int          // 서버 PK
    var nickname: String // 바뀔 수 있다
    var lastSeen: Date   // 계속 바뀐다

    static func == (l: Self, r: Self) -> Bool { l.id == r.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
```

`lastSeen`이 갱신될 때마다 다른 값이 되면 `List`의 행 신원이 흔들린다. [static 프로퍼티 문서](./static-stored-vs-computed-property.md)에서 본 문제와 같은 계열이다.

**② `Hashable`이 아닌 프로퍼티가 있을 때**

```swift
struct Wrapper: Hashable {
    let id: Int
    let handler: () -> Void      // 클로저는 Hashable이 아니다

    static func == (l: Self, r: Self) -> Bool { l.id == r.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
```

자동 합성 조건("모든 저장 프로퍼티가 `Hashable`")을 만족하지 못하므로 직접 써야 한다.

**③ 기존 타입을 extension으로 확장할 때**

원래 선언에서 채택하지 않았다면 자동 합성이 안 된다. Apple의 `GridPoint` 예제가 그 경우다.

**④ 계산 비용을 줄일 때**

프로퍼티가 아주 많은 타입에서 해시 계산이 병목이라면 일부만 쓸 수 있다. 다만 충돌이 늘어나므로 신중히 판단한다.

### 이 예제에서 확인할 것

`DevTechieCourse`는 `List`와 `navigationDestination`에서 쓰인다.

```swift
List(DevTechieCourse.sample) { course in
    NavigationLink(course.name, value: course)
}
.navigationDestination(for: DevTechieCourse.self) { course in
    DestinationView(title: course.name)
}
```

`Hashable`이 필요한 이유는 `navigationDestination(for:)`의 `where D : Hashable` 제약이다. [값과 목적지 연결 문서](./navigation-link-value-and-destination.md) 참조.

**여기에 `static var sample`(계산 프로퍼티) + `UUID()`가 겹친 문제가 있다.** `sample`을 읽을 때마다 새 `UUID`가 발급되므로 `id`가 매번 바뀐다. 자동 합성된 `==`가 `id`를 비교하니 `path`에 넣은 값과 `List`가 그리는 값이 일치하지 않을 수 있다. [static var vs static let 문서](./static-stored-vs-computed-property.md)에서 다룬 chapter-57과 같은 상황이다.

`static let`으로 바꾸는 것이 답이지만, `hash(into:)`와 `==`를 `id`만 쓰도록 고치는 것으로는 해결되지 않는다는 점을 유의한다. **`id` 자체가 매번 새로 만들어지기 때문이다.**

## 학습 체크리스트

- [ ] 주석 처리된 `hash(into:)`를 지운 상태로 컴파일이 되는지 확인한다 (자동 합성).
- [ ] 주석을 풀어 `id`만 넣도록 하고 여전히 컴파일되는지 확인한다.
- [ ] 그 상태에서 `==`는 자동 합성된 것이 남아 있음을 확인한다.
- [ ] `==`도 `id`만 비교하도록 직접 구현해 짝을 맞춘다.
- [ ] `hasher.combine(name)`만 넣고 `id`가 다른 두 인스턴스의 해시를 비교한다.
- [ ] `var hasher = Hasher(); hasher.combine(1); print(hasher.finalize())`를 두 번 실행해 값이 다른 것을 확인한다.
- [ ] `combine` 순서를 바꿔 해시가 달라지는 것을 확인한다.
- [ ] `hash(into:)` 안에서 `finalize()`를 호출해 보고 왜 안 되는지 확인한다.
- [ ] 클로저 프로퍼티를 추가해 자동 합성이 깨지는 것을 확인한다.
- [ ] `Set<DevTechieCourse>`를 만들어 `id`가 다르면 중복으로 저장되는지 확인한다.
- [ ] `static var sample`을 `static let`으로 바꾸고 `id`가 고정되는지 확인한다.
- [ ] Apple 문서의 `GridPoint` 예제를 그대로 구현해 `Set`에 넣어 본다.
- [ ] Java의 `record`와 Swift `struct`의 자동 생성 범위를 비교해 정리한다.

## 공식 참고 자료

- [Apple: Hashable](https://developer.apple.com/documentation/swift/hashable)
- [Apple: Hashable.hash(into:)](https://developer.apple.com/documentation/swift/hashable/hash(into:))
- [Apple: Hasher](https://developer.apple.com/documentation/swift/hasher)
- [Apple: Hasher.combine(_:)](https://developer.apple.com/documentation/swift/hasher/combine(_:))
- [Apple: Hasher.finalize()](https://developer.apple.com/documentation/swift/hasher/finalize())
- [Apple: Equatable](https://developer.apple.com/documentation/swift/equatable)
- [Apple: Identifiable](https://developer.apple.com/documentation/swift/identifiable)
- [Swift 공식 문서: Protocols — Adopting a Protocol Using a Synthesized Implementation](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/protocols/#Adopting-a-Protocol-Using-a-Synthesized-Implementation)
- [Swift 공식 문서: Inheritance — Overriding](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/inheritance/#Overriding)
- [Apple: Set](https://developer.apple.com/documentation/swift/set)
