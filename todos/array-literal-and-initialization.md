# `var posts = [Post]()` — 이 문법은 무엇인가

제네릭 타입 전반은 [별도 문서](./swift-generics.md)에, 기본 타입은 [여기](./swift-fundamental-types-and-comparison.md)에 정리했다. 이 문서는 **컬렉션을 초기화하는 여러 표기**를 다룬다.

## 질문이 나온 코드

`chapter-88/chapter-88/Services/NetworkManager.swift`

```swift
@Observable
final class NetworkManager {
    // TODO, 이건 무슨 문법이야?
    var posts = [Post]()
}
```

## 공부할 내용

### 결론 먼저

- **빈 배열을 만드는 이니셜라이저 호출**이다.
- `[Post]`가 타입 이름이고, 뒤의 `()`가 이니셜라이저 호출이다.
- `Array<Post>()`와 완전히 같다. `[Post]`는 축약 표기다.
- 같은 뜻을 나타내는 표기가 여럿 있고, 이 코드의 형태는 그중 하나다.

### 왜 헷갈리나 — `[Post]`는 타입 이름이다

`[Post]`를 "배열 리터럴"로 읽으면 혼란스럽다. **실제로는 타입 이름이다.**

```swift
Array<Post>          // 정식 표기
[Post]               // 축약 표기 — 완전히 같다
```

`Array`는 제네릭 타입이고 `[Post]`는 그것의 **문법적 설탕(syntactic sugar)** 이다. [제네릭 문서](./swift-generics.md)에서 다룬 대로 `Dictionary`, `Optional`도 같은 축약을 갖는다.

| 정식 | 축약 |
| --- | --- |
| `Array<Post>` | `[Post]` |
| `Dictionary<String, Double>` | `[String: Double]` |
| `Optional<String>` | `String?` |

**타입 이름 뒤에 `()`가 오면 이니셜라이저 호출**이다.

```swift
Post()               // Post 인스턴스 생성 (init이 있다면)
[Post]()             // [Post] 인스턴스 생성 → 빈 배열
Array<Post>()        // 같은 것
```

`Array`의 이니셜라이저 중 인자가 없는 것이 **빈 배열을 만든다.**

```swift
init()               // Creates a new, empty array.
```

이 프로젝트의 다른 코드와 비교하면 이해가 쉽다.

```swift
// chapter-80
private var formatters: [String: NumberFormatter] = [:]   // 빈 딕셔너리 리터럴
private var cancellableSet: Set<AnyCancellable> = []      // 빈 배열 리터럴 → Set으로 추론
```

### 같은 뜻을 나타내는 네 가지 표기

빈 배열을 만드는 방법이 여럿이다. **결과는 모두 같다.**

```swift
var posts = [Post]()              // ① 이니셜라이저 호출 — 이 코드
var posts: [Post] = []            // ② 타입 명시 + 빈 리터럴
var posts = Array<Post>()         // ③ 정식 제네릭 표기
var posts: [Post] = .init()       // ④ implicit member expression
```

**어느 쪽이 나은가**는 스타일 문제다. 다만 경향이 있다.

| 표기 | 특징 |
| --- | --- |
| `[Post]()` | 짧다. 타입이 **오른쪽**에 있다 |
| `: [Post] = []` | 타입이 **왼쪽**에 있어 선언부에서 바로 보인다 |
| `Array<Post>()` | 장황하지만 제네릭임이 드러난다 |
| `= .init()` | 타입 어노테이션이 필수 |

**②를 선호하는 사람이 많다.** 프로퍼티 목록을 훑을 때 타입이 일관된 위치(콜론 뒤)에 있어 읽기 쉽기 때문이다.

```swift
final class NetworkManager {
    var posts: [Post] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil
}
```

세 줄의 타입이 같은 열에 정렬된다. `[Post]()` 방식은 타입이 오른쪽에 있어 정렬이 깨진다.

**Apple 샘플 코드는 ②를 자주 쓴다.** 다만 강제 규칙은 아니고, [API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)도 이 부분은 규정하지 않는다.

### 빈 리터럴 `[]`가 동작하는 이유

```swift
var posts: [Post] = []
```

`[]`만 보면 어떤 타입의 배열인지 알 수 없다. **타입 어노테이션이 그것을 알려 준다.**

```swift
var posts = []          // ⚠️ 에러 — 타입을 추론할 수 없다
```

에러 메시지가 나온다.

```
error: empty collection literal requires an explicit type
```

`[Post]()` 방식은 타입이 표기에 포함되어 있으므로 어노테이션이 필요 없다. **그것이 이 형태의 장점이다.**

### 다른 초기화 방법들

빈 배열 외에도 여러 이니셜라이저가 있다.

```swift
// 값을 반복해 채운다
Array(repeating: 0, count: 5)          // [0, 0, 0, 0, 0]
[Int](repeating: 0, count: 5)          // 같은 것

// 시퀀스로부터
Array(1...5)                           // [1, 2, 3, 4, 5]
Array("hello")                         // ["h", "e", "l", "l", "o"]

// 리터럴로 직접
[1, 2, 3]                              // 타입은 [Int]로 추론
```

chapter-45의 grid 예제가 `repeating:`을 썼다.

```swift
Array(repeating: GridItem(.fixed(width), spacing: spacing), count: columns)
```

`Set`과 `Dictionary`도 같은 패턴이다.

```swift
Set<String>()                          // 빈 Set
[String: Int]()                        // 빈 딕셔너리
var d: [String: Int] = [:]             // 빈 딕셔너리 리터럴 — []가 아니다
```

**딕셔너리의 빈 리터럴은 `[:]`** 라는 점을 기억해 둘 만하다. `[]`는 빈 배열이다.

### `@Observable`과 함께 쓸 때

```swift
@Observable
final class NetworkManager {
    var posts = [Post]()
}
```

초기값이 있으므로 별도 `init`이 필요 없다. **`@Observable`은 초기화 방식에 관여하지 않는다** — 이 프로퍼티가 관찰 대상이 되는 것과 초기화 표기는 무관하다. [Observation 문서](./observation-framework-and-observable.md) 참조.

`var`인 이유는 나중에 값을 갈아 끼우기 때문이다.

```swift
posts = results.hits        // 통째로 교체
```

**컬렉션 자체의 변화도 `@Observable`이 추적한다.** `posts.append(...)`처럼 원소를 추가해도 뷰가 갱신된다.

### 정리

```text
[Post]() = 빈 배열을 만드는 이니셜라이저 호출

[Post]는 타입 이름 (Array<Post>의 축약)
  Array<Post> ≡ [Post]
  Dictionary<K,V> ≡ [K: V]
  Optional<T> ≡ T?

타입 이름 + () = 이니셜라이저 호출
  Array의 init()이 빈 배열을 만든다

같은 뜻의 네 표기
  [Post]()            타입이 오른쪽
  : [Post] = []       타입이 왼쪽 — 많이 선호된다
  Array<Post>()       정식 표기
  : [Post] = .init()  어노테이션 필수

var posts = []는 에러 — 빈 리터럴은 타입을 알려줘야 한다
딕셔너리의 빈 리터럴은 [:]다
```

## 학습 체크리스트

- [ ] `[Post]()`를 `Array<Post>()`로 바꿔도 동작하는지 확인한다.
- [ ] `var posts: [Post] = []`로 바꿔 보고 가독성을 비교한다.
- [ ] `var posts = []`를 시도해 컴파일 에러 메시지를 읽는다.
- [ ] `print(type(of: posts))`로 실제 타입을 확인한다.
- [ ] `[Post]`가 `Array<Post>`와 같은 타입인지 `==`로 비교해 본다 (`[Post].self == Array<Post>.self`).
- [ ] `Array(repeating: 0, count: 5)`와 `[Int](repeating: 0, count: 5)`를 비교한다.
- [ ] `Array(1...5)`, `Array("hello")`를 실행해 결과를 확인한다.
- [ ] 빈 딕셔너리를 `[]`로 만들려 시도해 `[:]`가 필요한 것을 확인한다.
- [ ] `Set<String>()`과 `var s: Set<String> = []`을 비교한다.
- [ ] `posts.append(...)`로 원소를 추가하고 뷰가 갱신되는지 확인한다.
- [ ] `Optional<String>()`이 되는지 시험해 본다.

## 공식 참고 자료

- [Apple: Array](https://developer.apple.com/documentation/swift/array)
- [Apple: Array.init()](https://developer.apple.com/documentation/swift/array/init())
- [Apple: Array.init(repeating:count:)](https://developer.apple.com/documentation/swift/array/init(repeating:count:))
- [Apple: Dictionary](https://developer.apple.com/documentation/swift/dictionary)
- [Apple: Set](https://developer.apple.com/documentation/swift/set)
- [Swift 공식 문서: Collection Types — Creating an Empty Array](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/collectiontypes/#Creating-an-Empty-Array)
- [Swift 공식 문서: Collection Types](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/collectiontypes/)
- [Swift 공식 문서: Types — Array Type](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/types/#Array-Type)
- [Swift 공식 문서: Types — Dictionary Type](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/types/#Dictionary-Type)
- [Swift 공식 문서: The Basics — Type Safety and Type Inference](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/#Type-Safety-and-Type-Inference)
