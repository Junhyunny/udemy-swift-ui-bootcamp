# `$0`의 정체 — shorthand argument name과 클로저 축약 단계

SwiftUI의 `{ }`가 왜 괄호 밖에 나올 수 있고 왜 `if`/`for`가 되는지는 [`ComponentName { }`의 정체](./closures-and-view-builders.md)에서 다뤘다. 이 문서는 **클로저 안에서 파라미터를 어떻게 지칭하는가**, 즉 `$0`·`$1`과 축약 문법을 파고든다.

## 질문이 나온 코드

`chapter-45/chapter-45/ContentView.swift`

```swift
let items = Array(1...20).map { "Item \($0)" }
```

파라미터 이름을 선언하지 않았는데 `$0`으로 값을 쓸 수 있다.

## 공부할 내용

### 결론 먼저

- `$0`은 Swift가 **자동으로 제공하는 이름**이다. 내가 선언하는 게 아니다.
- 숫자는 **몇 번째 파라미터인지**를 뜻한다. `$0`이 첫 번째, `$1`이 두 번째, `$2`가 세 번째다.
- 그래서 질문의 "몇 번째 파라미터인지에 따라 처리한다"는 이해가 정확하다.
- 쓸 수 있는 조건은 **inline 클로저**일 때다. 파라미터 목록과 `in`을 생략한 자리에서만 등장한다.
- `@State`의 `$`와는 **이름만 같고 완전히 다른 기능**이다. 그쪽은 [property wrapper의 projected value](./property-wrapper-dollar-sign.md)다.

Swift 공식 문서의 정의가 그대로다.

> Swift automatically provides shorthand argument names to inline closures, which can be used to refer to the values of the closure's arguments by the names `$0`, `$1`, `$2`, and so on.

### 예제 코드에 대입해 보기

`map`이 받는 클로저는 파라미터가 **하나**다. 배열의 요소 하나를 받아 새 값을 돌려준다.

```swift
// map의 클로저 타입: (Int) -> String
Array(1...20).map { "Item \($0)" }
//                          └── 첫 번째(그리고 유일한) 파라미터 = Int 요소
```

파라미터가 하나뿐이니 `$0`만 쓰인다. 이름을 붙여 쓰면 이렇게 된다.

```swift
Array(1...20).map { number in "Item \(number)" }
```

두 표현은 완전히 같은 코드다. `"Item \($0)"`의 `\( )`는 문자열 보간(string interpolation)이므로, 클로저 문법과는 별개다.

### 축약 5단계 — 어디까지 줄일 수 있는가

Swift 공식 문서는 `sorted(by:)` 하나를 다섯 번 고쳐 쓰며 축약 단계를 보여준다. 이 흐름을 외우면 어떤 클로저를 봐도 해석할 수 있다.

```swift
let names = ["Chris", "Alex", "Ewa", "Barry", "Daniella"]
```

**0단계. 이름 있는 함수를 넘긴다**

```swift
func backward(_ s1: String, _ s2: String) -> Bool {
    return s1 > s2
}
var reversedNames = names.sorted(by: backward)
```

**1단계. 클로저 표현식 전체 형태**

일반형은 다음과 같다.

```swift
{ (parameters) -> return type in
    statements
}
```

```swift
reversedNames = names.sorted(by: { (s1: String, s2: String) -> Bool in
    return s1 > s2
})
```

파라미터와 반환 타입이 **중괄호 안**으로 들어가고, `in` 키워드가 선언의 끝을 알린다.

> The start of the closure's body is introduced by the `in` keyword. This keyword indicates that the definition of the closure's parameters and return type has finished, and the body of the closure is about to begin.

**2단계. 타입 추론으로 타입을 지운다**

```swift
reversedNames = names.sorted(by: { s1, s2 in return s1 > s2 })
```

`sorted(by:)`가 `(String, String) -> Bool`을 요구한다는 걸 컴파일러가 알기 때문에 타입, `->`, 파라미터 괄호까지 지울 수 있다.

> It's always possible to infer the parameter types and return type when passing a closure to a function or method as an inline closure expression. As a result, you never need to write an inline closure in its fullest form when the closure is used as a function or method argument.

**3단계. 단일 표현식이면 `return`을 지운다**

```swift
reversedNames = names.sorted(by: { s1, s2 in s1 > s2 })
```

**4단계. shorthand argument name으로 파라미터 목록까지 지운다**

```swift
reversedNames = names.sorted(by: { $0 > $1 })
```

여기서 `in`도 사라진다. 몸통만 남았기 때문이다.

> If you use these shorthand argument names within your closure expression, you can omit the closure's argument list from its definition. The type of the shorthand argument names is inferred from the expected function type, and the highest numbered shorthand argument you use determines the number of arguments that the closure takes. The `in` keyword can also be omitted, because the closure expression is made up entirely of its body.

**5단계. 연산자 메서드를 그대로 넘긴다**

```swift
reversedNames = names.sorted(by: >)
```

`String`의 `>`가 이미 `(String, String) -> Bool` 이므로 그대로 함수 값이 된다.

**보너스. trailing closure까지 적용**

```swift
reversedNames = names.sorted { $0 > $1 }
```

인자가 클로저 하나뿐이라 괄호도 사라진다. 예제 코드의 `.map { ... }`이 바로 이 형태다.

```text
{ (s1: String, s2: String) -> Bool in return s1 > s2 }   전체
{ s1, s2 in return s1 > s2 }                             타입 추론
{ s1, s2 in s1 > s2 }                                    암시적 return
{ $0 > $1 }                                              shorthand
>                                                        연산자 메서드
```

### 중요한 규칙 — 가장 큰 번호가 인자 개수를 결정한다

`$1`만 쓰고 `$0`을 건너뛰어도 클로저는 **2개 인자**를 받는 것으로 해석된다.

```swift
// 두 번째 값을 채택하는 병합 규칙
var b: [String: String] = [:]
b.merge(a, uniquingKeysWith: { $1 })   // OK, 2개 인자로 추론
```

반대로 2개 인자를 요구하는 자리에서 `$0`만 쓰면 컴파일 에러다.

```swift
b.merge(a, uniquingKeysWith: { $0 })
// error: contextual closure type '(String, String) throws -> String'
//        expects 2 arguments, but 1 was used in closure body
```

인자를 **모두 무시**하고 싶으면 `_`로 명시적으로 받아야 한다.

```swift
b.merge(a, uniquingKeysWith: { _, new in new })
```

### 다양한 클로저 예제

**파라미터 1개 — `$0`만**

```swift
let numbers = [1, 2, 3, 4, 5, 6]

numbers.map { $0 * 2 }                    // [2, 4, 6, 8, 10, 12]
numbers.filter { $0 % 2 == 0 }            // [2, 4, 6]
numbers.first { $0 > 3 }                  // Optional(4)
numbers.contains { $0 > 5 }               // true
numbers.forEach { print($0) }
numbers.allSatisfy { $0 > 0 }             // true
numbers.partition { $0 > 3 }              // 재배치 후 경계 인덱스

["1", "x", "3"].compactMap { Int($0) }    // [1, 3]
[[1, 2], [3]].flatMap { $0 }              // [1, 2, 3]
```

**파라미터 2개 — `$0`, `$1`**

```swift
numbers.reduce(0) { $0 + $1 }             // 21  ($0=누적값, $1=요소)
numbers.reduce(0, +)                      // 21  연산자 메서드
numbers.sorted { $0 > $1 }                // 내림차순
numbers.min { $0 % 3 < $1 % 3 }           // 비교 규칙을 직접 지정

zip(["a", "b"], [1, 2]).map { "\($0)\($1)" }   // ["a1", "b2"]
```

`reduce`에서 `$0`과 `$1`의 의미가 다른 점이 특히 중요하다. `$0`은 요소가 아니라 **누적값**이다. 헷갈리면 이름을 붙이는 게 낫다.

```swift
numbers.reduce(0) { total, number in total + number }
```

**enumerated — 튜플이 하나의 파라미터로 온다**

```swift
items.enumerated().map { "\($0.offset): \($0.element)" }
```

`enumerated()`의 요소는 `(offset:element:)` 튜플 **하나**다. 그래서 `$0.offset`, `$0.element`가 되고 `$1`은 없다. 이름을 풀어 쓰면 이렇게 된다.

```swift
items.enumerated().map { index, item in "\(index): \(item)" }
```

파라미터 하나로 온 튜플이 두 이름으로 분해되는 것이라, `$0`/`$1`로 쓸 때와 형태가 달라 보이는 지점이다.

**key path 축약 — `$0` 없이 더 짧게**

```swift
struct User { let name: String; let age: Int }
let users: [User] = []

users.map { $0.name }        // 클로저
users.map(\.name)            // key path, 동일한 결과
```

**정렬 기준을 여러 단계로**

```swift
users.sorted {
    $0.age == $1.age ? $0.name < $1.name : $0.age < $1.age
}
```

**클로저를 받는 내 함수 만들기**

```swift
func measure<T>(_ label: String, _ work: () -> T) -> T {
    let result = work()
    print("\(label) 완료")
    return result
}

let value = measure("계산") { 1 + 2 }
```

**클로저를 저장하는 프로퍼티 — `@escaping`**

```swift
struct CardView: View {
    let title: String
    let onTap: () -> Void      // 저장되는 클로저

    var body: some View {
        Text(title).onTapGesture { onTap() }
    }
}
```

함수 호출이 끝난 뒤에도 살아 있어야 하는 클로저는 파라미터에 `@escaping`이 필요하다. 프로퍼티로 저장하는 경우는 그 자체가 escaping이다.

### `$0`을 쓰면 안 되는 경우

- **클로저가 중첩될 때.** 안쪽 `$0`이 어느 클로저의 것인지 읽는 사람이 알기 어렵다. 안쪽·바깥쪽 중 하나는 이름을 붙인다.

  ```swift
  // 나쁨
  groups.map { $0.items.filter { $0.isActive } }
  // 좋음
  groups.map { group in group.items.filter { $0.isActive } }
  ```

- **`reduce`처럼 파라미터의 역할이 비대칭일 때.** `$0`이 누적값이라는 사실이 코드에 드러나지 않는다.
- **클로저 몸통이 여러 줄일 때.** `$0`이 아래쪽에서 등장하면 무엇인지 되짚어야 한다.
- **타입이 애매해 컴파일러가 헤맬 때.** 타입을 명시하면 에러 메시지도 훨씬 좋아진다.

  > Nonetheless, you can still make the types explicit if you wish, and doing so is encouraged if it avoids ambiguity for readers of your code.

### 클로저의 세 가지 형태

`$0`이 왜 "inline 클로저"에서만 나오는지는 클로저의 분류를 보면 납득된다.

> - Global functions are closures that have a name and don't capture any values.
> - Nested functions are closures that have a name and can capture values from their enclosing function.
> - Closure expressions are unnamed closures written in a lightweight syntax that can capture values from their surrounding context.

`$0`은 세 번째, **이름 없는 클로저 표현식**을 위한 편의 기능이다. 이름 있는 함수는 이미 파라미터 이름이 있으니 필요가 없다.

Swift가 제공하는 축약 최적화는 공식 문서에 네 가지로 정리돼 있다.

> - Inferring parameter and return value types from context
> - Implicit returns from single-expression closures
> - Shorthand argument names
> - Trailing closure syntax

예제 코드 `Array(1...20).map { "Item \($0)" }` 한 줄에 이 네 가지가 모두 들어 있다.

## 학습 체크리스트

- [ ] `.map { "Item \($0)" }`을 `{ number in "Item \(number)" }`로 바꿔 결과가 같은지 확인한다.
- [ ] `sorted(by:)`를 전체 형태부터 `sorted(by: >)`까지 5단계로 직접 축약해 본다.
- [ ] `numbers.reduce(0) { $0 + $1 }`에서 `$0`과 `$1`을 `print`로 찍어 누적값과 요소를 구분한다.
- [ ] 2개 인자를 요구하는 클로저에 `$0`만 써서 나오는 컴파일 에러 메시지를 직접 본다.
- [ ] `{ $1 }`만 쓴 클로저가 왜 2개 인자로 추론되는지 설명한다.
- [ ] `enumerated().map { $0.offset }`과 `.map { i, item in i }`가 같은 이유를 설명한다.
- [ ] `users.map { $0.name }`을 `users.map(\.name)`으로 바꿔 본다.
- [ ] 중첩 클로저에서 `$0`이 겹칠 때 어느 쪽 값이 잡히는지 확인하고 이름을 붙여 개선한다.
- [ ] 클로저를 파라미터로 받는 함수를 직접 만들고 trailing closure로 호출한다.
- [ ] `@State`의 `$`와 클로저의 `$0`이 왜 서로 무관한지 한 문장으로 정리한다.

## 공식 참고 자료

- [Swift 공식 문서: Closures](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/closures/)
- [Swift 공식 문서: Closures — Shorthand Argument Names](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/closures/#Shorthand-Argument-Names)
- [Swift 공식 문서: Closures — Closure Expression Syntax](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/closures/#Closure-Expression-Syntax)
- [Swift 공식 문서: Closures — Trailing Closures](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/closures/#Trailing-Closures)
- [Swift 공식 문서: Closures — Escaping Closures](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/closures/#Escaping-Closures)
- [Swift 공식 문서: Functions](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/functions/)
- [Apple: Sequence.map(_:)](https://developer.apple.com/documentation/swift/sequence/map(_:))
- [Apple: Sequence.reduce(_:_:)](https://developer.apple.com/documentation/swift/sequence/reduce(_:_:))
- [Apple: Sequence.sorted(by:)](https://developer.apple.com/documentation/swift/sequence/sorted(by:))
