# `at:` 문법의 정체와 `IndexSet`

이 문서는 원본 코드의 TODO 두 개(`at:` 신텍스, `IndexSet`과 `at offset`)를 함께 다룬다. 둘 다 같은 한 줄을 설명하는 질문이기 때문이다.

## 질문이 나온 코드

`chapter-29/chapter-29/ContentView.swift`의 `.onDelete(perform: delete(at:))`와 `func delete(at offsets: IndexSet)`

## 공부할 내용

### `at`은 문법 키워드가 아니라 **argument label**이다

Swift에서 함수 파라미터는 이름을 두 개 가질 수 있다.

> "Each function parameter has both an argument label and a parameter name. The argument label is used when calling the function; each argument is written in the function call with its argument label before it. The parameter name is used in the implementation of the function. By default, parameters use their parameter name as their argument label."

두 개를 다르게 주려면 **앞에 label, 뒤에 이름**을 공백으로 나란히 쓴다.

> "You write an argument label before the parameter name, separated by a space."

```swift
func someFunction(argumentLabel parameterName: Int) { }
```

이 규칙을 그대로 대입하면 끝난다.

```swift
func delete(at offsets: IndexSet) { ... }
//          ^^ label   ^^^^^^^ 이름
```

- **`at`** — 호출할 때 쓰는 이름. `delete(at: someIndexSet)`
- **`offsets`** — 함수 본문에서 쓰는 이름. `courses.remove(atOffsets: offsets)`

`at`이라는 단어 자체에 기능은 없다. `delete(at:)`이 영어 문장처럼 읽히게 하려고 고른 것뿐이고, `func delete(indices offsets: IndexSet)`라고 써도 동작은 같다. label이 필요 없으면 `_`를 쓴다.

> "If you don't want an argument label for a parameter, write an underscore (`_`) instead of an explicit argument label for that parameter."

### `delete(at:)`는 "호출"이 아니라 **함수를 가리키는 이름**이다

```swift
.onDelete(perform: delete(at:))
```

여기서 `delete(at:)`은 함수를 호출하는 게 아니다. 괄호 안에 인자가 없는 것에서 알 수 있다. 이것은 **함수 자체를 값으로 넘기는 표기**이고, `at:`은 "argument label이 `at`인 그 함수"를 특정하기 위해 붙는다.

Swift는 이름이 같고 label만 다른 함수를 여러 개 둘 수 있어서, 이렇게 label까지 포함한 이름(`delete(at:)`)으로 어느 것인지 지목한다. 아래 세 가지는 모두 같은 뜻이다.

```swift
.onDelete(perform: delete(at:))
.onDelete(perform: delete)                  // 후보가 하나뿐이면 생략 가능
.onDelete { offsets in delete(at: offsets) } // 클로저로 직접 작성
```

### `onDelete`가 왜 그 함수를 받아주나

> `func onDelete(perform action: Optional<(IndexSet) -> Void>) -> some DynamicViewContent`

`(IndexSet) -> Void` 타입을 요구한다. `delete(at:)`의 타입이 정확히 그것이라 그대로 들어맞는다. label은 타입에 포함되지 않는다.

역할도 문서에 적혀 있다.

> "Sets the deletion action for the dynamic view. You must delete the corresponding item within `action`, as it will be called after the row has already been removed from the view."
>
> "SwiftUI passes a set of indices to the closure that's relative to the dynamic view's underlying collection of data."

즉 **행은 SwiftUI가 화면에서 이미 지웠고, 원본 데이터에서 지우는 건 내 몫**이다. 그래서 `delete` 안에서 `courses.remove(...)`를 반드시 호출해야 한다.

### `IndexSet`은 왜 `Int` 하나가 아닌가

> "A collection of unique integer values that represent the indexes of elements in another collection."

**중복 없는 정수들의 집합**이다. 편집 모드에서 여러 행을 한 번에 지울 수 있으므로 삭제 대상이 하나라고 가정할 수 없고, 그래서 `Int`가 아니라 집합을 받는다. 스와이프로 한 줄만 지워도 원소가 하나인 `IndexSet`이 온다. 코드의 `print("deleting this offset: ", offsets)`으로 실제로 무엇이 오는지 확인할 수 있다.

받은 `IndexSet`은 배열에 그대로 넘긴다.

> `mutating func remove(atOffsets offsets: IndexSet)`
>
> "Removes all the elements at the specified offsets from the collection."

여기서도 `atOffsets`가 label, `offsets`가 이름이다. 인덱스를 하나씩 순회하며 지우면 앞쪽을 지운 뒤 뒤쪽 인덱스가 밀려 어긋나는데, `remove(atOffsets:)`는 그 문제를 알아서 처리한다.

## 학습 체크리스트

- [ ] `func delete(at offsets: IndexSet)`을 `func delete(indices offsets: IndexSet)`으로 바꾸고 호출부를 함께 고쳐 label이 임의의 이름임을 확인한다.
- [ ] label을 `_`로 바꿔 `delete(someSet)` 형태로 호출해 본다.
- [ ] 파라미터 이름만 쓰는 `func delete(offsets: IndexSet)`로 바꾸면 호출부가 `delete(offsets:)`가 되는지 확인한다.
- [ ] `.onDelete(perform: delete(at:))`를 `.onDelete { delete(at: $0) }`로 바꿔 같은 동작인지 본다.
- [ ] 편집 모드에서 여러 행을 선택해 삭제하고 `print`로 `IndexSet`에 값이 몇 개 오는지 확인한다.
- [ ] `remove(atOffsets:)` 대신 `for i in offsets { courses.remove(at: i) }`로 바꿔 인덱스가 밀리는 문제를 직접 겪어 본다.
- [ ] `delete` 안에서 `courses.remove(...)`를 지우면 화면과 데이터가 어떻게 어긋나는지 관찰한다.

## 참고 자료

- [The Swift Programming Language: Functions — Argument Labels and Parameter Names](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/functions/)
- [The Swift Programming Language: Expressions](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/expressions/)
- [Apple: IndexSet](https://developer.apple.com/documentation/foundation/indexset)
- [Apple: DynamicViewContent.onDelete(perform:)](https://developer.apple.com/documentation/swiftui/dynamicviewcontent/ondelete(perform:))
- [Apple: RangeReplaceableCollection.remove(atOffsets:)](https://developer.apple.com/documentation/swift/rangereplaceablecollection/remove(atoffsets:))
- [Apple: DynamicViewContent](https://developer.apple.com/documentation/swiftui/dynamicviewcontent)
- [Swift API Design Guidelines: Naming](https://www.swift.org/documentation/api-design-guidelines/)
