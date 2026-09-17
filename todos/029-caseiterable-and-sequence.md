# `CaseIterable`과 `Sequence` — 열거형 전체 사례 순회

## 질문이 나온 코드

`chapter-104/chapter-104/Move.swift`와 `ContentView.swift`

```swift
enum Move: String, CaseIterable {
    case rock = "🪨"
    case paper = "📝"
    case scissors = "✂️"
}

ForEach(Move.allCases, id: \.self) { move in
    // 각 수에 대한 버튼
}
```

## 공부할 내용

### `CaseIterable`이 제공하는 것

`CaseIterable`은 타입의 모든 값 또는 사례를 하나의 컬렉션으로 제공한다는 프로토콜이다. 핵심 요구사항은 타입 프로퍼티 `allCases`다.

```swift
protocol CaseIterable {
    associatedtype AllCases: Collection
        where AllCases.Element == Self

    static var allCases: AllCases { get }
}
```

`Move.allCases`를 사용하면 열거형의 사례를 다시 배열에 중복 작성하지 않고 순회할 수 있다.

```swift
for move in Move.allCases {
    print(move.rawValue)
}
```

컴파일러가 자동으로 합성한 `allCases`는 사례를 선언한 순서대로 제공한다. 현재 코드에서는 `rock`, `paper`, `scissors` 순서다.

### 자동 합성 조건

연관값이 없는 enum이 `CaseIterable`을 채택하면 Swift가 `allCases` 구현을 자동 합성한다.

```swift
enum Direction: CaseIterable {
    case north, south, east, west
}
```

연관값이 있는 사례는 가능한 값의 수를 컴파일러가 정할 수 없으므로 자동 합성되지 않는다.

```swift
enum Route: CaseIterable {
    case home
    case detail(id: Int) // 자동 allCases 합성 불가
}
```

이 경우 의미 있는 전체 사례를 직접 정의해야 한다.

```swift
enum Route: CaseIterable {
    case home
    case detail(id: Int)

    static let allCases: [Route] = [
        .home,
        .detail(id: 0)
    ]
}
```

다만 `detail(id:)`에 가능한 모든 `Int`를 나열한 것은 아니므로, 직접 구현한 `allCases`가 도메인에서 무엇을 뜻하는지 명확히 정해야 한다.

### Swift 표준 라이브러리에는 일반 `Iterable` 프로토콜이 없다

Java의 `Iterable`, Kotlin의 `Iterable`, Python의 iterable 개념과 달리 Swift 표준 라이브러리에서 반복의 중심 프로토콜 이름은 `Sequence`다.

```text
Sequence
  └── Collection
       ├── BidirectionalCollection
       └── RandomAccessCollection
```

- `Sequence`: 값을 한 번에 하나씩 순서대로 제공한다. `for-in`의 기본 요구사항이다.
- `Collection`: 여러 번 안정적으로 순회할 수 있고 `startIndex`, `endIndex`, subscript 같은 위치 기반 접근을 제공한다.
- `CaseIterable`: 타입의 전체 사례를 `AllCases`라는 `Collection`으로 제공한다.
- `IteratorProtocol`: `next()`로 다음 원소를 꺼내는 iterator 자체를 표현한다.

즉 `CaseIterable`은 객체 자체를 곧바로 반복 가능하게 만드는 프로토콜이 아니다. **타입이 반복 가능한 컬렉션인 `allCases`를 제공하게 한다.** 실제 `for-in`은 `Move`가 아니라 `Move.allCases`를 순회한다.

```swift
// 가능
for move in Move.allCases { }

// Move 자체는 Sequence가 아니므로 이런 의미의 사용은 불가능
// for move in Move { }
```

### `ForEach`에서 `id: \.self`가 별도로 필요한 이유

`CaseIterable`은 사례 목록만 제공하고 각 원소의 SwiftUI identity는 제공하지 않는다. `ForEach`에서 `id: \.self`를 사용하려면 원소가 `Hashable`이어야 한다.

```swift
ForEach(Move.allCases, id: \.self) { move in
    Text(move.rawValue)
}
```

현재처럼 연관값이 없는 enum은 각 사례가 안정적으로 구분되므로 `\.self`를 identity로 쓰기에 적합하다. `CaseIterable`, `Hashable`, `Identifiable`은 각각 다른 문제를 해결한다.

| 프로토콜 | 해결하는 문제 |
|---|---|
| `CaseIterable` | 전체 사례를 어떻게 얻는가 |
| `Hashable` | 값을 해시하고 동등성을 비교할 수 있는가 |
| `Identifiable` | 값의 안정적인 identity가 무엇인가 |

### raw value와도 별개다

`String` raw value는 화면에 표시할 값을 제공하고, `CaseIterable`은 사례 목록을 제공한다.

```swift
Move.allCases.map(\.rawValue) // ["🪨", "📝", "✂️"]
```

둘은 함께 쓰기 편하지만 서로를 대신하지 않는다. `CaseIterable`에는 raw value가 필요하지 않고, raw-value enum이라고 해서 자동으로 `allCases`가 생기지도 않는다.

## 체크리스트

- [ ] `Move.allCases`의 타입과 출력 순서를 확인한다.
- [ ] `CaseIterable`을 제거했을 때 `allCases` 사용부의 컴파일 오류를 확인한다.
- [ ] 연관값이 있는 사례를 추가해 자동 합성이 불가능해지는 것을 확인한다.
- [ ] `Sequence`, `Collection`, `IteratorProtocol`, `CaseIterable`의 역할을 구분한다.
- [ ] `CaseIterable`과 `Hashable`이 `ForEach`에서 각각 무엇을 제공하는지 설명한다.
- [ ] `String` raw value를 제거해도 `allCases`가 동작하는지 확인한다.

## 공식 참고 자료

- [Apple: CaseIterable](https://developer.apple.com/documentation/swift/caseiterable)
- [The Swift Programming Language: Iterating over Enumeration Cases](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/enumerations/#Iterating-over-Enumeration-Cases)
- [Apple: Sequence](https://developer.apple.com/documentation/swift/sequence)
- [Apple: Collection](https://developer.apple.com/documentation/swift/collection)
- [Apple: IteratorProtocol](https://developer.apple.com/documentation/swift/iteratorprotocol)
- [Apple: ForEach](https://developer.apple.com/documentation/swiftui/foreach)
