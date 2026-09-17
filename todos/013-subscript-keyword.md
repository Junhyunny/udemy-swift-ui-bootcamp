# `subscript` 키워드 — `[ ]` 표기를 직접 정의하기

## 질문이 나온 코드

`chapter-146/chapter-146/ViewModels/OnboardingViewModel.swift`

```swift
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
```

사용하는 쪽은 이렇다.

```swift
var currentStep: OnboardingStep {
    guard let currentIndex = currentIndex else {
        return steps.first!
    }
    return steps[safe: currentIndex] ?? steps.first!
}
```

`subscript`가 무엇이고 언제 쓰는지가 질문이다.

## 공부할 내용

### 결론 먼저

`subscript`는 **`인스턴스[...]` 표기를 내가 정의하는 문법**이다. 함수나 계산 프로퍼티와 하는 일은 같지만, 호출 표기가 `.foo(...)`나 `.foo`가 아니라 **대괄호**라는 점만 다르다.

```text
array.element(at: 3)   → 메서드
array.count            → 프로퍼티
array[3]               → subscript
```

`Array[0]`, `Dictionary["key"]`처럼 우리가 매일 쓰는 대괄호 표기도 전부 표준 라이브러리가 `subscript`로 정의해 둔 것이다. 언어에 박힌 특별한 문법이 아니라 **우리도 똑같이 만들 수 있는 멤버**다.

### 기본 문법

계산 프로퍼티와 모양이 거의 같다. 파라미터와 반환 타입이 붙는다는 점만 다르다.

```swift
struct TimesTable {
    let multiplier: Int

    subscript(index: Int) -> Int {
        get {
            return multiplier * index
        }
        set(newValue) {
            // 쓰기가 필요 없으면 set을 생략한다
        }
    }
}

let threeTimesTable = TimesTable(multiplier: 3)
threeTimesTable[6]   // 18
```

`get`만 있으면 read-only이고, 이때는 `get { }` 껍데기도 생략할 수 있다. 질문의 코드가 이 형태다.

```swift
subscript(safe index: Int) -> Element? {
    return indices.contains(index) ? self[index] : nil   // get 생략형
}
```

`var`나 `func` 키워드가 없고 이름도 없다. **이름이 없는 대신 대괄호가 이름 역할**을 한다.

### 어디에 정의할 수 있나

`class`, `struct`, `enum`, 그리고 `protocol`에 정의할 수 있다. `extension`으로 **남이 만든 타입에 나중에 추가**할 수도 있다. 질문의 코드가 바로 그 경우로, 표준 라이브러리의 `Array`에 새 subscript를 덧붙였다.

```swift
protocol Container {
    associatedtype Item
    subscript(i: Int) -> Item { get }   // 프로토콜 요구사항으로도 쓴다
}
```

### 인자 레이블 — `[safe: index]`가 되는 이유

`subscript(safe index: Int)`에서 `safe`는 **인자 레이블(argument label)**이고 `index`는 내부 파라미터 이름이다. 함수와 규칙이 완전히 같다.

레이블이 중요한 이유는 **기존 `array[0]`과 충돌하지 않기 때문**이다. Swift는 인자 레이블까지 포함해서 시그니처를 구분하므로, 아래 둘은 별개의 멤버로 공존한다.

```swift
steps[0]           // 표준 라이브러리의 subscript(_ index: Int) -> Element
steps[safe: 0]     // 우리가 추가한 subscript(safe index: Int) -> Element?
```

만약 레이블 없이 `subscript(_ index: Int) -> Element?`로 정의했다면, 기존 것과 파라미터가 같고 반환 타입만 달라 **호출할 때마다 모호해진다.** 레이블은 멋 부리기가 아니라 **충돌 회피 장치**다. [Swift의 함수 오버로딩 문서](./009-swift-function-overloading.md)와 이어진다.

호출부에서 읽히는 모습도 다르다.

```text
steps[safe: i]   → "안전하게 i번째"  — 반환값이 옵셔널이라는 신호가 표기에 드러난다
steps[i]         → "i번째"          — 범위를 벗어나면 크래시
```

### 파라미터는 여러 개일 수 있다

subscript는 파라미터를 몇 개든 받을 수 있고, 타입도 자유다. 2차원 행렬이 대표적인 예다.

```swift
struct Matrix {
    let rows: Int, columns: Int
    var grid: [Double]

    subscript(row: Int, column: Int) -> Double {
        get {
            return grid[(row * columns) + column]
        }
        set {
            grid[(row * columns) + column] = newValue
        }
    }
}

var matrix = Matrix(rows: 2, columns: 2)
matrix[0, 1] = 1.5
```

`matrix[0, 1]`처럼 콤마로 여러 값을 받는 표기는 subscript 말고는 만들 방법이 없다. **여러 개의 좌표로 하나의 값을 지목**하는 상황이 subscript가 가장 잘 어울리는 자리다.

다만 `inout` 파라미터는 받을 수 없고, 기본값은 지정할 수 있다.

### 타입 subscript

인스턴스가 아니라 **타입 자체에** 붙일 수도 있다. `static`(또는 class에서 재정의를 허용하려면 `class`)을 붙인다.

```swift
enum Planet: Int {
    case mercury = 1, venus, earth, mars

    static subscript(n: Int) -> Planet {
        return Planet(rawValue: n)!
    }
}

let earth = Planet[3]   // .earth
```

[`static` 타입 프로퍼티 문서](./015-static-type-properties-and-implicit-init.md), [`enum` raw value 문서](./011-enum-raw-values.md)와 함께 보면 좋다.

### 제네릭 subscript

subscript에도 제네릭 파라미터와 `where` 절을 붙일 수 있다([SE-0148](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0148-generic-subscripts.md)).

```swift
extension Collection {
    subscript<Indices: Sequence>(indices: Indices) -> [Element]
    where Indices.Element == Index {
        return indices.map { self[$0] }
    }
}
```

`@Observable`이나 `Binding`이 `$viewModel.currentIndex`처럼 동작하는 것도 내부적으로는 `subscript(dynamicMember:)`([SE-0252](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0252-keypath-dynamic-member-lookup.md))라는 제네릭 subscript다. [`@State`와 `_viewModel` 문서](./046-state-property-wrapper-backing-storage.md)에서 이어서 다룬다.

### 언제 쓰고, 언제 쓰지 않는가

| 상황 | 적합한 형태 |
|---|---|
| 여러 원소를 담은 것에서 **하나를 지목**해 꺼낸다 | subscript |
| 좌표·키 같은 **인덱스 성격의 인자**로 접근한다 | subscript |
| 인자 없이 인스턴스의 **속성 하나**를 읽는다 | 계산 프로퍼티 |
| **동작을 수행**하거나 부수 효과가 있다 | 메서드 |
| 비용이 크거나 실패할 수 있어 **`throws`가 필요**하다 | 메서드 (subscript는 `throws` 불가) |

판단 기준은 **"컬렉션에서 원소를 꺼내는 느낌인가"**다. `cache[key]`, `matrix[r, c]`, `steps[safe: i]`는 자연스럽고, `user[validate: true]` 같은 건 메서드여야 한다. 대괄호는 "가볍고 즉시 반환된다"는 인상을 주므로, 네트워크 호출처럼 무거운 일을 subscript 뒤에 숨기면 읽는 사람을 속이게 된다.

### 이 코드에 적용하면

```swift
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
```

- `extension Array`이므로 **모든 배열**에 생긴다. `Element`는 `Array`의 제네릭 파라미터를 그대로 쓴 것이다.
- 반환 타입이 `Element?`인 이유는 **범위를 벗어나면 `nil`을 주기 위해서**다. 기본 `array[i]`는 범위를 벗어나면 옵셔널이 아니라 **런타임 크래시**다.
- `indices`는 `0..<count` 범위이고, `contains(index)`로 먼저 검사한 뒤에만 `self[index]`를 호출한다.
- 호출부 `steps[safe: currentIndex] ?? steps.first!`는 "인덱스가 유효하면 그 step, 아니면 첫 step"이 된다.

`Array` 대신 `Collection`으로 일반화하려 하면 한 가지가 걸린다. `Collection`의 `Index`는 `Int`가 아닐 수 있다(`String.Index` 등). 그래서 파라미터 타입을 `Index`로 바꿔야 한다.

```swift
extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
```

`Array`에만 쓸 거라면 지금 코드로 충분하다. `Index == Int`가 보장되기 때문이다.

## 체크리스트

- [ ] `subscript`를 계산 프로퍼티·메서드와 각각 한 문장으로 구분해 설명한다.
- [ ] read-only subscript에서 `get { }`을 생략할 수 있는 조건을 확인한다.
- [ ] `subscript(safe:)`에서 레이블을 지우고 컴파일해 어떤 오류가 나는지 직접 본다.
- [ ] `steps[10]`과 `steps[safe: 10]`을 각각 호출해 크래시와 `nil`의 차이를 확인한다.
- [ ] 파라미터 2개짜리 subscript를 만들어 `matrix[0, 1]` 표기를 써 본다.
- [ ] `static subscript`를 enum에 정의해 `Type[...]` 표기를 만들어 본다.
- [ ] `extension Collection`으로 바꿔 보고 `Int` 대신 `Index`를 써야 하는 이유를 설명한다.
- [ ] subscript로 만들면 안 되는 경우(무거운 작업, `throws` 필요)를 예로 들어 본다.

## 공식 참고 자료

- [The Swift Programming Language: Subscripts](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/subscripts/)
- [The Swift Programming Language: Declarations — Subscript Declaration](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/declarations/#Subscript-Declaration)
- [The Swift Programming Language: Extensions](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/extensions/)
- [The Swift Programming Language: Generics](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/generics/)
- [Swift Standard Library: Array — subscript(_:)](https://developer.apple.com/documentation/swift/array/subscript(_:)-8gyuu)
- [Swift Standard Library: Collection — indices](https://developer.apple.com/documentation/swift/collection/indices-1itsy)
- [SE-0148: Generic Subscripts](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0148-generic-subscripts.md)
- [SE-0252: Key Path Member Lookup](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0252-keypath-dynamic-member-lookup.md)
