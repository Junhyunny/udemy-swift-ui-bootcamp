# 옵셔널 총정리 — 선언부터 언래핑, 강제 언래핑까지

옵셔널 관련 내용을 **한 파일에 모은 문서**다. 개별 주제를 깊게 파고든 문서가 이미 있으므로, 여기서는 전체 지도를 그리고 흩어져 있던 것과 어디에도 없던 것을 채운다.

| 이미 있는 문서 | 다루는 범위 |
| --- | --- |
| [`if`의 조건 결합과 옵셔널 바인딩](./003-if-conditions-and-optional-binding.md) | `,`가 AND인 이유, 바인딩 스코프, 단축 평가 |
| [`guard` 키워드](./004-guard-keyword.md) | 조기 탈출, `else`의 의무, 바인딩이 이후에도 사는 이유 |
| [타입에 붙는 `!`](./005-implicitly-unwrapped-optional.md) | 암시적 언래핑 옵셔널(IUO)과 그 위험 |
| [API 응답 모델에 옵셔널을 써야 하나](./118-optional-in-api-models.md) | 서버 계약과 옵셔널 설계 |

**이 문서가 새로 채우는 것** — 옵셔널의 정체(`enum`), 언래핑 8가지 비교, 옵셔널 체이닝 규칙, `??`의 결합성과 단축 평가, `map`/`flatMap` 차이, 중첩 옵셔널, 패턴 매칭, 컴파일 에러 읽는 법, 이 저장소의 강제 언래핑 실제 사례, `Codable`과 옵셔널, SwiftUI에서의 옵셔널.

모든 예제는 **Swift 6.3.3에서 직접 실행해 확인**했다. 출력이 실린 것은 전부 실측값이다.

## 1부 — 옵셔널의 정체: 특별한 문법이 아니라 `enum`이다

`Int?`는 문법 설탕이고 실체는 표준 라이브러리의 `enum`이다.

```swift
enum Optional<Wrapped> {
    case none
    case some(Wrapped)
}
```

직접 확인한 결과다.

```swift
let a: Int? = 5
switch a {
case .some(let v): print(".some(\(v))")
case .none:        print(".none")
}
print(type(of: a), Int?.self == Optional<Int>.self)
```

```text
.some(5)
Optional<Int> true
```

`Int?`, `Optional<Int>`, `.some(5)`가 전부 같은 것이다. **이 사실 하나로 나머지가 설명된다.**

- `switch`와 패턴 매칭이 되는 이유 → 그냥 `enum`이니까
- `nil`은 특별한 포인터가 아니라 `.none` 케이스
- `map`, `flatMap` 같은 메서드가 있는 이유 → 타입이니까 메서드를 가질 수 있다
- 옵셔널을 옵셔널로 감쌀 수 있는 이유 → `Optional<Optional<Int>>`가 성립하니까

## 2부 — 언래핑하는 8가지 방법

| 방법 | 형태 | 실패하면 | 주로 쓰는 곳 |
| --- | --- | --- | --- |
| `if let` | `if let x = opt { }` | 블록을 건너뜀 | 값이 있을 때만 하는 일 |
| `guard let` | `guard let x else { return }` | 탈출 | 함수 전제 조건 |
| `??` | `opt ?? 기본값` | 기본값 사용 | 대체값이 있을 때 |
| 옵셔널 체이닝 | `opt?.prop` | 전체가 `nil` | 연쇄 접근 |
| `map` / `flatMap` | `opt.map { }` | `nil` 유지 | 값 변환 |
| 패턴 매칭 | `for case let x?` | 건너뜀 | 컬렉션·`switch` |
| 강제 언래핑 | `opt!` | **크래시** | 거의 쓰지 않는다 |
| IUO | `var x: Int!` | **크래시** | 초기화 2단계뿐 |

### 2-1. `if let` — 축약 문법

Swift 5.7(SE-0345)부터 같은 이름이면 우변을 생략한다.

```swift
if let name { print(name) }          // if let name = name 과 같다
```

조건 결합과 스코프 규칙은 [003 문서](./003-if-conditions-and-optional-binding.md)에 자세하다. 핵심만 옮기면 **`,`는 AND이고, 앞 조건이 실패하면 뒤는 평가되지 않는다.**

### 2-2. `guard let` — 바인딩이 살아남는다

`if let`과의 결정적 차이는 **바인딩된 값의 수명**이다.

```swift
guard let user else { return }
// 여기서부터 함수 끝까지 user 를 쓸 수 있다
```

`if let`은 블록 안에서만, `guard let`은 이후 전체에서 쓸 수 있다. 그래서 중첩이 사라진다. 자세한 것은 [004 문서](./004-guard-keyword.md)에 있다.

`[weak self]` 클로저에서 쓰는 축약도 같은 문법이다.

```swift
run { [weak self] in
    guard let self else { return }
    if let name { print(name) }      // self.name 의 축약
}
```

### 2-3. `??` — 우결합이고 단축 평가한다

두 가지 성질을 확인했다.

```swift
func expensive() -> Int { print("expensive() 호출됨"); return 99 }
let v1: Int? = 7
print(v1 ?? expensive())        // expensive 는 호출되지 않는다

let v2: Int? = nil
let v3: Int? = nil
print(v2 ?? v3 ?? 0)            // 우결합이라 체이닝된다
```

```text
7
0
```

`expensive() 호출됨`이 출력되지 않았다. **왼쪽에 값이 있으면 오른쪽은 평가조차 하지 않는다.** 그래서 `?? 무거운계산()`이 안전하다.

우결합이므로 `a ?? b ?? c`는 `a ?? (b ?? c)`로 묶인다. 대체값을 여러 단계로 둘 수 있다.

### 2-4. 옵셔널 체이닝 — 결과는 **항상** 옵셔널이다

가장 헷갈리는 규칙이다.

```swift
struct Person { var name: String; var pet: Pet? }   // name 은 비옵셔널
let p: Person? = ...

let n = p?.name           // String?  ← name 이 비옵셔널인데도 옵셔널
let s = p?.pet?.speak()   // String?  ← 두 단계여도 한 겹
```

```text
p?.name: Optional<String> | p?.pet?.speak(): Optional<String>
```

규칙 둘이다.

1. **체이닝에 `?`가 하나라도 있으면 결과는 옵셔널이 된다.** 접근하는 멤버가 비옵셔널이어도 그렇다.
2. **몇 단계를 거치든 한 겹으로 평탄화된다.** `String??`이 되지 않는다.

중간에 하나라도 `nil`이면 나머지는 평가되지 않고 전체가 `nil`이 된다. `??`와 묶어 쓰면 깔끔하다.

```swift
let title = article?.author?.name ?? "익명"
```

### 2-5. `map`과 `flatMap` — 중첩이 생기냐 아니냐

옵셔널도 타입이므로 변환 메서드를 갖는다.

```swift
let str: String? = "42"
let m  = str.map { Int($0) }      // Int??  ← 중첩된다
let fm = str.flatMap { Int($0) }  // Int?   ← 평탄화
```

```text
map: Optional<Optional<Int>> | flatMap: Optional<Int>
```

**클로저가 옵셔널을 돌려주면 `flatMap`, 아니면 `map`.** `Int(String)`은 실패할 수 있어 `Int?`를 반환하므로 `flatMap`이 맞다.

배열에서는 `compactMap`이 같은 역할을 한다.

```swift
let mixed: [Int?] = [1, nil, 3, nil, 5]
mixed.compactMap { $0 }          // [1, 3, 5]
```

### 2-6. 패턴 매칭 — `for case let x?`

`enum`이므로 패턴 매칭이 자연스럽다. `?`는 `.some(...)`의 축약이다.

```swift
for case let x? in mixed { picked.append(x) }   // nil 은 건너뛴다
```

```text
for case let x?: [1, 3, 5] | compactMap: [1, 3, 5]
```

`compactMap`과 결과가 같다. 순회하면서 다른 일도 해야 하면 `for case`, 변환만 하면 `compactMap`이 읽기 좋다.

`switch`에서도 쓸 수 있다.

```swift
switch value {
case .some(let v) where v > 10: print("큰 값 \(v)")
case .some(let v):              print("값 \(v)")
case .none:                     print("없음")
}
```

### 2-7. 강제 언래핑 — 실제로 무엇이 일어나나

`nil`이면 프로그램이 죽는다. 실행해서 확인한 메시지다.

```text
crash.swift:5: Fatal error: Unexpectedly found nil while unwrapping an Optional value
```

**정당한 경우는 좁다.**

- 리터럴이라 실패가 논리적으로 불가능하고, 실패하면 곧 프로그래머 실수인 경우
- 테스트 코드 (실패하면 테스트가 깨지는 게 맞다)
- 초기화 순서가 언어로 표현되지 않는 경우 → 그래도 IUO가 낫다

그 외에는 `guard let`, `??`, 옵셔널 체이닝 중 하나로 대체된다.

### 2-8. IUO — 타입에 붙는 `!`

`var x: Int!`는 "옵셔널이지만 쓸 때마다 자동으로 풀어라"는 선언이다. 안전장치를 스스로 끄는 것이므로 사용처가 매우 좁다. [005 문서](./005-implicitly-unwrapped-optional.md)에 정리되어 있다.

## 3부 — 중첩 옵셔널

옵셔널은 자동으로 평탄화되지 **않는다.** 대표적으로 딕셔너리다.

```swift
let dict: [String: Int?] = ["a": 1, "b": nil]
dict["b"]      // Int?? — 값: Optional(nil)
dict["zzz"]    // Int?? — 값: nil
```

```text
dict["b"]: Optional<Optional<Int>> | 값: Optional(nil)
dict["zzz"]: nil
```

**두 `nil`의 의미가 다르다.**

- `Optional(nil)` = 키는 있는데 값이 `nil`
- `nil` = 키 자체가 없음

이 구분이 필요 없으면 `??`로 한 번에 접는다.

```swift
let v = dict["b"] ?? nil        // Int?
```

예외가 하나 있다. **`try?`는 Swift 5부터 평탄화된다.**

```swift
func mayFail() throws -> Int? { 3 }
let t = try? mayFail()          // Int? — Int?? 가 아니다
```

```text
try? mayFail(): Optional<Int> | 값: Optional(3)
```

대신 "함수가 실패했다"와 "함수가 `nil`을 돌려줬다"를 구분할 수 없게 된다. 구분이 필요하면 `do-catch`를 쓴다. [오류 처리 방식들](./100-swift-error-handling-forms.md) 참조.

## 4부 — 컴파일 에러 읽는 법

옵셔널 관련 에러는 문구가 거의 하나로 수렴한다.

```swift
let a: Int? = 1
let sum = a + 1
let cmp = a < b
```

```text
error: value of optional type 'Int?' must be unwrapped to a value of type 'Int'
```

**"연산 전에 풀어라"** 는 뜻이다. 산술도, 대소 비교도 옵셔널끼리는 안 된다.

반면 **`nil` 비교와 동등 비교는 된다.**

```swift
(nil as Int?) == nil    // true
Int?(1) == 1            // true — 비옵셔널이 자동으로 옵셔널로 승격된다
```

`Optional`이 `Equatable`을 조건부로 따르기 때문이다. `Comparable`은 따르지 않으므로 `<`는 막힌다. "`nil`이 1보다 작은가"에 답이 없기 때문이다.

## 5부 — 이 저장소의 강제 언래핑 실제 사례

조사 결과 앱 코드에서 11곳이 나왔다. 성격별로 나뉜다.

| 위치 | 코드 | 위험도 |
| --- | --- | --- |
| `chapter-61/ContentView.swift:127` | `AsyncImage(url: URL(string: imageURL)!)` | **높음 — 실제로 터진다** |
| `chapter-61/ContentView.swift:75` | `WebView(url: URL(string: url)!)` | 높음 |
| `chapter-80/ViewModel.swift:109` | `formatter.string(from:)!` | 높음 |
| `chapter-94/TimerViewModel.swift:48` | `@Published var leftTime: Date!` | 중간 (IUO) |
| `chapter-104/GameViewModel.swift:44` | `opponentMove!` | 중간 |
| `chapter-115`, `chapter-117` | `try! ModelContainer(...)` | 낮음 (앱 시작 시 실패는 치명적) |
| `chapter-49/ContentView.swift:14` | `URL(string: UIApplication.openSettingsURLString)!` | 낮음 (상수) |

### `chapter-61`이 실제로 터지는 이유 — 검증

`URL(string:)`이 언제 `nil`을 주는지 최신 SDK에서 직접 확인했다.

```text
https://a.com          OK
httpsgoogle.com        OK  ← 스킴이 없어도 통과한다
(빈 문자열)             nil ❌
"  " (공백)             OK  → %20%20
한글.com                OK  → %ED%95%9C%EA%B8%80.com
https://a.com/a b      OK  → .../a%20b
```

**요즘 Foundation의 `URL(string:)`은 매우 관대하다.** 거의 다 통과하고, `nil`이 되는 대표 사례가 **빈 문자열**이다.

그런데 `chapter-61`의 호출부를 보면 이렇다.

```swift
CardView(imageURL: article.urlToImage ?? "")     // nil → 빈 문자열
...
AsyncImage(url: URL(string: imageURL)!)          // 빈 문자열 → nil → 💥
```

`urlToImage`가 `nil`인 기사가 하나라도 오면 `?? ""`가 빈 문자열을 만들고, `URL(string: "")`이 `nil`을 돌려주고, `!`가 앱을 죽인다. **옵셔널을 `?? ""`로 없앴다가 강제 언래핑으로 되살린, 가장 나쁜 조합이다.**

고치는 방법은 옵셔널을 끝까지 옵셔널로 들고 가는 것이다.

```swift
CardView(imageURL: article.urlToImage.flatMap(URL.init(string:)))   // URL?
...
AsyncImage(url: imageURL) { ... }      // AsyncImage 는 nil URL 을 placeholder 로 처리한다
```

파일의 `FIXME`가 지적하는 내용이며, 여기에 "왜 실제로 터지는가"의 근거가 더해진 셈이다.

## 6부 — `Codable`과 옵셔널

디코딩 동작을 직접 확인했다.

```swift
struct A: Codable { var name: String; var nick: String? }
```

| JSON | 결과 |
| --- | --- |
| `{"name":"준현"}` | 성공, `nick = nil` |
| `{"name":"준현","nick":null}` | 성공, `nick = nil` |
| `{"nick":"J"}` | **실패** — `keyNotFound: name` |
| `{"name":null,"nick":"J"}` | **실패** — `valueNotFound: String` |

정리하면 이렇다.

- **옵셔널 프로퍼티는 키가 없어도, `null`이어도 통과한다.** 둘을 구분하지 않는다.
- **비옵셔널 프로퍼티는 키가 없거나 `null`이면 디코딩 전체가 실패한다.** 필드 하나 때문에 응답 전부를 잃는다.

인코딩 방향도 확인했다.

```swift
JSONEncoder().encode(A(name: "준현", nick: nil))
// {"name":"준현"}     ← nil 은 키 자체가 사라진다
```

서버가 `null`을 명시적으로 받아야 하면 `encodeIfPresent`가 아니라 직접 인코딩해야 한다. 어떤 필드를 옵셔널로 둘지에 대한 설계 판단은 [118 문서](./118-optional-in-api-models.md)에 있다.

## 7부 — SwiftUI에서의 옵셔널

### `ViewBuilder` 안의 `if let`

`body` 안에서도 옵셔널 바인딩이 된다.

```swift
if let message {
    Text(message)
}
```

`@ViewBuilder`가 `if`를 처리하기 때문이다. [041 문서](./041-viewbuilder-vs-view-struct.md) 참조. `guard`는 값을 반환해야 하므로 `body` 안에서 쓸 수 없다.

### 옵셔널을 그대로 받는 API들

SwiftUI는 옵셔널을 강제로 풀지 말라고 설계되어 있다.

```swift
AsyncImage(url: someURL)                       // nil 이면 placeholder
.navigationDestination(item: $selected) { }    // nil 이면 이동 안 함 — 140 문서 참조
.sheet(item: $selectedItem) { }                // nil 이면 안 띄움
Text(optionalString ?? "")                     // Text 는 옵셔널을 안 받는다
```

**옵셔널이 곧 "표시 안 함" 상태로 쓰인다.** 억지로 풀어서 넘기면 5부의 `chapter-61` 같은 문제가 생긴다.

### `Binding`과 옵셔널

`@State var value: String?`에 `TextField`를 붙이려면 옵셔널 바인딩을 비옵셔널로 바꿔야 한다.

```swift
TextField("이름", text: Binding(
    get: { value ?? "" },
    set: { value = $0.isEmpty ? nil : $0 }
))
```

`$value`는 `Binding<String?>`이라 `TextField`가 받지 못한다.

## 8부 — 선택 기준

```text
값이 없을 때 무엇을 할 것인가?

  대신 쓸 값이 있다            → ??
  그 경우 아무것도 안 한다      → if let / 옵셔널 체이닝
  함수를 계속할 수 없다         → guard let (+ 조기 return)
  값을 변환만 한다             → map / flatMap
  컬렉션에서 골라낸다           → compactMap / for case let x?
  절대 nil 일 수 없다          → 그래도 guard let 을 쓰고 assertionFailure 를 남긴다
  정말로 죽어야 한다            → ! (리터럴·테스트 한정)
```

**경험칙 — 옵셔널을 없애려 하지 말고 끝까지 들고 간다.** `?? ""`처럼 억지로 채운 기본값은 문제를 숨겼다가 더 나쁜 자리에서 터뜨린다. SwiftUI API 대부분이 옵셔널을 그대로 받도록 설계된 이유다.

## 학습 체크리스트

- [ ] `switch`로 옵셔널을 `.some`/`.none`으로 분해해 본다.
- [ ] `Int?.self == Optional<Int>.self`가 `true`인 것을 확인한다.
- [ ] `if let name = name`을 `if let name`으로 줄여 본다.
- [ ] 같은 로직을 `if let`과 `guard let`으로 각각 작성해 중첩 깊이를 비교한다.
- [ ] `??` 오른쪽에 `print`가 있는 함수를 두고 왼쪽에 값이 있을 때 호출되지 않는 것을 확인한다.
- [ ] `a ?? b ?? c`가 우결합으로 묶이는 것을 확인한다.
- [ ] 비옵셔널 프로퍼티를 옵셔널 체이닝으로 접근해 결과 타입이 옵셔널이 되는 것을 본다.
- [ ] 3단계 체이닝의 결과가 세 겹이 아니라 한 겹인 것을 확인한다.
- [ ] 같은 클로저로 `map`과 `flatMap`을 호출해 타입 차이를 본다.
- [ ] `[String: Int?]`에서 없는 키와 `nil` 값 키의 결과를 구분해 본다.
- [ ] `try?`가 중첩 옵셔널을 만들지 않는 것을 확인한다.
- [ ] 옵셔널끼리 `<` 비교를 시도해 에러 문구를 읽는다.
- [ ] `chapter-61`의 `urlToImage`가 `nil`인 응답을 만들어 크래시를 재현한다.
- [ ] 같은 코드를 `flatMap(URL.init(string:))`으로 고쳐 크래시가 사라지는지 확인한다.
- [ ] 옵셔널·비옵셔널 필드에 키 없음과 `null`을 각각 넣어 디코딩 결과 4가지를 확인한다.
- [ ] `nil` 프로퍼티를 인코딩해 키가 사라지는 것을 확인한다.
- [ ] `Binding<String?>`을 `TextField`에 직접 넘겨 에러를 본 뒤 커스텀 `Binding`으로 고친다.

## 공식 참고 자료

- [Swift Book: The Basics — Optionals](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/#Optionals)
- [Swift Book: Optional Chaining](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/optionalchaining/)
- [Swift Book: Patterns — Optional Pattern](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/patterns/#Optional-Pattern)
- [Swift Book: Error Handling](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/errorhandling/)
- [Apple: Optional](https://developer.apple.com/documentation/swift/optional)
- [Apple: Optional.map(_:)](https://developer.apple.com/documentation/swift/optional/map(_:))
- [Apple: Optional.flatMap(_:)](https://developer.apple.com/documentation/swift/optional/flatmap(_:))
- [Apple: Sequence.compactMap(_:)](https://developer.apple.com/documentation/swift/sequence/compactmap(_:))
- [Apple: KeyedDecodingContainer.decodeIfPresent(_:forKey:)](https://developer.apple.com/documentation/swift/keyeddecodingcontainer/decodeifpresent(_:forkey:)-7ucyl)
- [Apple: URL.init(string:)](https://developer.apple.com/documentation/foundation/url/init(string:))
- [SE-0345: `if let` shorthand for shadowing an existing optional variable](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0345-if-let-shorthand.md)
- [SE-0230: Flatten nested optionals resulting from `try?`](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0230-flatten-optional-try.md)
