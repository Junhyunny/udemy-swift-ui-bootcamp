# `where` 키워드 — 반복문 필터부터 연관 타입 제약까지

## 질문이 나온 코드

`chapter-140/chapter-140/ContentView.swift`

```swift
func note(at location: CGPoint) -> PianoNote? {
    for index in PianoNote.blackKeys.indices
    where blackKeyRect(at: index).contains(location) {
        return PianoNote.blackKeys[index]
    }
    ...
}
```

`for ... in ... where ...` 형태가 낯설다. `where`가 무엇이고 어디에 쓸 수 있는지가 질문이다.

`chapter-156/chapter-156/ContentView.swift`에서 같은 키워드가 **전혀 다른 자리**에 다시 등장했다.

```swift
protocol SegmentItem: Hashable & CaseIterable & RawRepresentable
where RawValue == String {
    var icon: String { get }
    var color: Color { get }
}

struct ReusableSegmentedControl<T: SegmentItem>: View
where T.RawValue == String {
    // ...
}
```

반복문의 `where`와 생김새는 같은데 하는 일이 다르다. **왜 쓰는지, 언제 쓰는지**가 이어진 질문이다.

## 공부할 내용

### 결론 먼저

`where`는 **"이 조건을 만족할 때만"**을 붙이는 한 단어다. 쓰이는 자리가 여러 곳이지만 크게 두 부류다.

| 부류 | 판정 시점 | 예 |
|---|---|---|
| **값 조건** | 런타임 | `for ... where`, `switch case ... where`, `catch ... where` |
| **타입 제약** | 컴파일 타임 | `func f<T>() where T: P`, `extension X where ...` |

이름은 같지만 하는 일이 다르다. 앞의 것은 **값을 걸러내고**, 뒤의 것은 **어떤 타입에만 코드를 허용한다.**

### 1. `for ... in ... where` — 반복 대상 걸러내기

질문에 나온 형태다.

```swift
for index in PianoNote.blackKeys.indices
where blackKeyRect(at: index).contains(location) {
    return PianoNote.blackKeys[index]
}
```

`where` 조건이 `false`인 반복은 **본문을 건너뛰고 다음 원소로 넘어간다.** 다음 코드와 같은 뜻이다.

```swift
for index in PianoNote.blackKeys.indices {
    guard blackKeyRect(at: index).contains(location) else { continue }
    return PianoNote.blackKeys[index]
}
```

`continue`를 쓴 형태와 동작이 같다. 차이는 읽는 방식이다.

```text
for ... where 조건 { 본문 }   → "조건을 만족하는 것만 돌린다"가 선언부에 보인다
for ... { guard ... continue } → 본문을 읽어야 필터가 있다는 걸 안다
```

`filter`와도 비교해 볼 만하다.

```swift
for index in indices.filter({ rect(at: $0).contains(location) }) { ... }
```

결과는 같지만 `filter`는 **걸러낸 결과를 담을 새 배열을 만든다.** `where`는 배열을 만들지 않고 반복하면서 건너뛴다. 원소가 많으면 이 차이가 의미 있다.

주의할 점이 하나 있다. `where`는 **건너뛸 뿐 반복을 멈추지 않는다.** 조건을 만족하는 첫 원소에서 끝내고 싶으면 위 코드처럼 본문에서 `return`하거나 `first(where:)`를 쓴다.

```swift
// 같은 동작을 표준 라이브러리로 표현하면
PianoNote.blackKeys.indices
    .first(where: { blackKeyRect(at: $0).contains(location) })
    .map { PianoNote.blackKeys[$0] }
```

### 2. `switch case ... where` — 패턴에 조건 덧붙이기

패턴은 맞지만 **값까지 조건을 걸고 싶을 때** 쓴다.

```swift
switch velocity {
case let v where v > 100:
    print("세게 침")
case let v where v > 0:
    print("약하게 침")
default:
    print("안 침")
}
```

`enum`의 연관값에도 쓴다.

```swift
enum KeyEvent {
    case pressed(PianoNote)
    case released(PianoNote)
}

switch event {
case .pressed(let note) where note.isBlackKey:
    print("검은 건반 누름")
case .pressed(let note):
    print("\(note.name) 누름")
case .released:
    break
}
```

**위에서부터 순서대로 판정**하므로, 조건이 좁은 case를 먼저 둬야 한다. 넓은 case를 위에 두면 아래 case는 영원히 실행되지 않는다.

### 3. `if case` / `guard case` / `while case`와 함께

```swift
if case .pressed(let note) = event, note.isBlackKey {
    // if 문에서는 콤마로 조건을 잇는 편이 일반적이다
}

guard case .pressed(let note) = event else { return }
```

`switch`가 아닌 자리에서는 `where` 대신 콤마(`,`)로 조건을 잇는 형태를 더 자주 쓴다. [`guard` 키워드 문서](./guard-keyword.md)와 [`if` 조건과 옵셔널 바인딩 문서](./if-conditions-and-optional-binding.md)에서 다룬다.

### 4. `catch ... where` — 오류를 조건으로 나누기

```swift
do {
    try audioManager.setAudio()
} catch let error as AudioError where error == .setupFailed {
    print("오디오 준비 실패")
} catch {
    print("그 밖의 오류: \(error)")
}
```

오류 타입은 같지만 값에 따라 다르게 처리할 때 쓴다. [Swift 오류 처리 문서](./swift-error-handling-forms.md)와 이어진다.

### 5. 제네릭 `where` 절 — 타입에 조건 걸기

여기서부터는 **성격이 완전히 다르다.** 값을 거르는 게 아니라 **컴파일러에게 타입 조건을 알려 준다.**

```swift
func allEqual<C: Collection>(_ items: C) -> Bool
where C.Element: Equatable {
    guard let first = items.first else { return true }
    return items.allSatisfy { $0 == first }
}
```

`C.Element: Equatable`은 `<C: Collection>` 자리에 쓸 수 없다. **연관 타입에 거는 조건은 `where` 절에만 쓸 수 있기 때문**이다.

extension에도 붙는다.

```swift
extension Array where Element == PianoNote {
    var blackKeyCount: Int {
        count { $0.isBlackKey }
    }
}
```

이러면 `[PianoNote]`에만 `blackKeyCount`가 생기고 `[Int]`에는 생기지 않는다. 조건부 확장(conditional extension)이라고 부른다.

protocol에도 쓸 수 있다.

```swift
protocol KeyboardStyling where Self: View {
    var accentColor: Color { get }
}
```

제네릭 쪽 `where`는 [Swift 제네릭 문서](./swift-generics.md)에 더 정리되어 있다.

### 6. `where`가 **유일한** 표현 수단인 경우 — 연관 타입 제약

여기가 chapter-156의 사례이고, **`where`를 배워야 하는 진짜 이유**다.

```swift
protocol SegmentItem: Hashable & CaseIterable & RawRepresentable
where RawValue == String {
    var icon: String { get }
    var color: Color { get }
}
```

`RawRepresentable`은 `RawValue`라는 **연관 타입(associated type)**을 갖는다.

```swift
protocol RawRepresentable {
    associatedtype RawValue
    var rawValue: RawValue { get }
    init?(rawValue: RawValue)
}
```

여기서 "raw value가 `String`인 `RawRepresentable`"을 표현하고 싶은데, **`&`로는 쓸 수 없다.**

```swift
protocol SegmentItem: RawRepresentable & (RawValue == String)   // ❌ 그런 문법은 없다
```

`&`는 "이 프로토콜도 따른다"만 표현할 수 있고, **"그 프로토콜의 연관 타입이 무엇이다"는 표현하지 못한다.** 그 일을 하는 것이 `where`다.

```swift
protocol SegmentItem: RawRepresentable where RawValue == String { }   // ✓
```

이게 있어야 `Text(item.rawValue)`가 컴파일된다. `where`가 없으면 `rawValue`의 타입은 그저 "어떤 `RawValue`"일 뿐이라 `Text`에 넣을 수 없다.

제약의 형태는 두 가지다.

| 형태 | 뜻 | 예 |
|---|---|---|
| `T.X == 구체타입` | 같은 타입 요구(same-type requirement) | `where RawValue == String` |
| `T.X: 프로토콜` | 적합성 요구(conformance requirement) | `where Element: Equatable` |

Swift 5.7부터는 **주 연관 타입(primary associated type)**이 지정된 프로토콜에 한해 꺾쇠로 줄여 쓸 수 있다([SE-0346](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0346-light-weight-same-type-syntax.md)).

```swift
func f(_ items: any Collection<String>) { }              // 줄인 형태
func f<C: Collection>(_ x: C) where C.Element == String { }   // 원래 형태
```

`RawRepresentable`에는 주 연관 타입이 지정되어 있지 않으므로, 이 코드는 **여전히 `where`를 써야 한다.**

### 7. 제약을 겹쳐 쓰면 상속된다

```swift
struct ReusableSegmentedControl<T: SegmentItem>: View
where T.RawValue == String {
```

`SegmentItem` 선언에 이미 `where RawValue == String`이 있으므로, `T: SegmentItem`이면 **`T.RawValue == String`은 자동으로 따라온다.** 이 `where` 절은 지워도 컴파일된다.

남겨 두면 제약이 선언부에 드러나 읽기 좋고, 지우면 중복이 사라진다. 어느 쪽도 틀리지 않는다. [프로토콜 합성 문서](./protocol-composition-and-type-combining.md)에서 이어서 다룬다.

### 두 부류를 한눈에

```text
값 조건 (런타임에 걸러냄)
  for x in xs where x > 0 { }
  switch v { case let n where n > 0: }
  catch let e where e.code == 1 { }
        ↓
  "이 값일 때만 실행"

타입 제약 (컴파일 타임에 허용 여부 결정)
  func f<T>() where T: Equatable { }
  extension Array where Element == Int { }
        ↓
  "이 타입일 때만 존재"
```

헷갈리면 **"조건이 값에 관한 것인가, 타입에 관한 것인가"**를 먼저 본다.

### 어디에 쓸 수 있는지 정리

| 자리 | 문법 | 부류 |
|---|---|---|
| for-in 루프 | `for x in xs where 조건 { }` | 값 |
| switch case | `case 패턴 where 조건:` | 값 |
| catch 절 | `catch 패턴 where 조건 { }` | 값 |
| do-catch의 case | `case let e as E where 조건` | 값 |
| 함수·메서드 | `func f<T>(...) where 제약` | 타입 |
| 타입 선언 | `struct S<T> where T: P { }` | 타입 |
| extension | `extension X where 제약 { }` | 타입 |
| protocol | `protocol P where Self: C { }` | 타입 |
| associatedtype | `associatedtype E where E: Equatable` | 타입 |
| 연관 타입 제약 | `where RawValue == String` | 타입 (**`&`로 대체 불가**) |

Swift 5.3부터는 제네릭이 아닌 문맥의 선언에도 `where`를 붙일 수 있게 확장되었다([SE-0267](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0267-where-on-contextually-generic.md)).

### 이 코드에 적용하면

```swift
for index in PianoNote.blackKeys.indices
where blackKeyRect(at: index).contains(location) {
    return PianoNote.blackKeys[index]
}
```

- 검은 건반 인덱스를 전부 훑되
- 터치 좌표를 포함하는 사각형만 본문으로 들어가고
- 첫 번째로 맞는 건반을 바로 반환한다

`filter`로 배열을 새로 만들지 않고, `guard ... continue`보다 의도가 선언부에 드러난다. 건반이 5개뿐이라 성능 차이는 없지만 **읽기 쉬운 쪽**을 고른 형태다.

## 체크리스트

- [ ] `for ... where`를 `guard ... continue`로 바꿔 쓰고 동작이 같은지 확인한다.
- [ ] `for ... where`와 `filter` 후 반복의 차이를 배열 생성 관점에서 설명한다.
- [ ] `where`가 반복을 멈추지 않고 건너뛴다는 것을 `print`로 확인한다.
- [ ] `first(where:)`로 같은 로직을 표현해 본다.
- [ ] enum 연관값에 `switch case ... where`를 적용하고 case 순서를 바꿔 본다.
- [ ] `catch ... where`로 같은 오류 타입을 값에 따라 나눠 처리한다.
- [ ] `extension Array where Element == PianoNote`를 만들어 다른 배열 타입에는 안 생기는지 확인한다.
- [ ] 값 조건 `where`와 타입 제약 `where`를 각각 한 문장으로 구분해 설명한다.
- [ ] `protocol P: RawRepresentable where RawValue == String`을 만들고, `where`를 지우면 `Text(item.rawValue)`가 왜 실패하는지 확인한다.
- [ ] 연관 타입 제약을 `&`로 표현하려 시도해 보고 불가능함을 확인한다.
- [ ] same-type 요구(`==`)와 conformance 요구(`:`)를 각각 써 본다.
- [ ] `ReusableSegmentedControl`의 `where T.RawValue == String`을 지워도 컴파일되는 이유를 설명한다.
- [ ] `any Collection<String>`과 `where C.Element == String`을 서로 바꿔 써 본다.

## 공식 참고 자료

- [The Swift Programming Language: Control Flow](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/controlflow/)
- [The Swift Programming Language: Statements](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/statements/)
- [The Swift Programming Language: Patterns](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/patterns/)
- [The Swift Programming Language: Generics](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/generics/)
- [The Swift Programming Language: Error Handling](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/errorhandling/)
- [SE-0267: `where` clauses on contextually generic declarations](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0267-where-on-contextually-generic.md)
- [The Swift Programming Language: Generics — Generic Where Clauses](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/generics/#Generic-Where-Clauses)
- [The Swift Programming Language: Generics — Associated Types with a Generic Where Clause](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/generics/#Associated-Types-with-a-Generic-Where-Clause)
- [Swift Standard Library: RawRepresentable](https://developer.apple.com/documentation/swift/rawrepresentable)
- [SE-0346: Lightweight same-type requirements for primary associated types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0346-light-weight-same-type-syntax.md)
