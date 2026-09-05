# `ForEach`의 `id`와 `\.self` key path

## 질문이 나온 코드

`chapter-18/chapter-18/ContentView.swift`의 `ForEach(images, id: \.self)`

## 공부할 내용

### 왜 `id`를 넘겨야 하는가 — SwiftUI는 목록의 각 항목을 구분할 수단이 필요하다

`ForEach`는 "데이터 배열을 돌면서 view를 찍어내는 반복문"이 아니라, **식별된 데이터(identified data)로부터 view를 만들어 내는 구조체**다. Apple 문서의 정의부터 그렇다.

> "A structure that computes views on demand from an underlying collection of identified data."

SwiftUI는 화면을 다시 그릴 때 이전 view 목록과 새 view 목록을 비교해서 **무엇이 추가·삭제·이동됐는지** 판단한다. 이때 "3번째 항목"처럼 순서로 따지면 중간에 하나가 삭제됐을 때 그 뒤 항목이 전부 다른 것으로 오인된다. 그래서 각 항목에 **순서와 무관하게 그 항목을 가리키는 고유한 값**, 즉 identity가 필요하다.

그래서 `ForEach`는 둘 중 하나를 요구한다.

> "Either the collection's elements must conform to `Identifiable` or you need to provide an `id` parameter to the `ForEach` initializer."

지금 코드의 원소는 그냥 `String`이라 `Identifiable`이 아니다. 그래서 `id:`를 직접 넘겨야 하고, 안 넘기면 컴파일되지 않는다.

identity가 흔들리면 실제로 무엇이 깨지는지도 알아 둘 필요가 있다. 어떤 항목의 `id`가 바뀌면 SwiftUI는 그것을 **다른 항목이 새로 생긴 것**으로 취급하므로, 그 view가 들고 있던 `@State` 같은 상태와 진행 중이던 애니메이션이 사라진다. `View.id(_:)` 문서가 같은 원리를 짧게 정리한다.

> "When the proxy value specified by the `id` parameter changes, the identity of the view — for example, its state — is reset."

이 갤러리는 항목마다 상태를 들고 있지 않아서 지금은 차이가 드러나지 않지만, 각 셀에 `@State`를 두거나 삭제 애니메이션을 붙이는 순간 체감된다.

### 왜 `.self`가 아니라 `\.self`인가 — 값이 아니라 key path를 넘기는 자리다

`id:` 파라미터가 받는 것은 **값**이 아니라 **key path**다. "원소에서 식별자를 어떻게 꺼낼지"를 알려주는 경로를 넘기는 것이다. 배열 전체에 대해 한 번 넘기면, `ForEach`가 각 원소에 그 경로를 적용해 식별자를 얻는다.

Swift에서 key path를 쓰려면 역슬래시로 시작하는 **key-path expression** 문법을 써야 한다.

> "A key-path expression refers to a property or subscript of a type. ... They have the following form: `\<type name>.<path>`"

여기서 타입 이름은 추론될 수 있으면 생략 가능하다. `\String.self`를 `\.self`로 줄여 쓸 수 있는 이유가 이것이다.

> "The type name can be omitted in contexts where type inference can determine the implied type."

그리고 경로 자리에 `self`를 쓰면 **identity key path**가 된다.

> "The path can refer to `self` to create the identity key path (`\.self`). The identity key path refers to a whole instance, so you can use it to access and change all of the data stored in a variable in a single step."

정리하면 `\.self`는 "원소의 어떤 프로퍼티가 아니라 **원소 값 그 자체**를 식별자로 쓰겠다"는 뜻이다. `images`가 `["photo1", "photo2", ...]`이므로 문자열 `"photo1"` 자체가 그 항목의 id가 된다.

반면 `.self`는 key path가 아니라 **값에 대한 멤버 접근 표현식**이다. `id:` 자리에 넣을 대상 값이 없으므로 문법적으로 성립하지 않는다. 두 표기의 차이는 역슬래시 하나지만 **"값을 넘기느냐, 값을 꺼내는 방법을 넘기느냐"**라는 다른 층위의 이야기다.

```swift
let s = "photo1"
let path = \String.self        // KeyPath<String, String> — 꺼내는 방법
let value = s[keyPath: path]   // "photo1" — 꺼낸 값
```

### `\.self`를 쓸 때 주의할 점

- 식별자로 쓰이는 타입은 `Hashable`이어야 한다. `String`은 `Hashable`이라 그대로 동작한다.
- 값 자체가 id이므로 **배열에 같은 값이 두 번 들어가면 id가 겹친다.** `ForEach`의 초기화 문서가 "uniquely identifies"라고 말하는 전제가 깨지는 것이라, 중복이 생길 수 있는 데이터에는 부적절하다. 지금 배열은 `photo1`~`photo5`로 모두 다르므로 문제없다.
- 값이 바뀌면 id도 함께 바뀐다. 편집 가능한 목록이라면 원소를 `Identifiable`로 만들고 변하지 않는 별도 `id`를 두는 편이 안전하다.

## 학습 체크리스트

- [ ] `ForEach(images) { ... }`처럼 `id:`를 빼 보고 어떤 컴파일 오류가 나는지 읽는다.
- [ ] `id: .self`로 써 보고 `id: \.self`와 오류 메시지가 어떻게 다른지 확인한다.
- [ ] `\String.self`와 `\.self`가 같은 것임을 확인하고, Quick Help로 `id:` 파라미터의 타입이 `KeyPath`임을 본다.
- [ ] `images`에 `"photo1"`을 한 번 더 넣어 id가 중복됐을 때 목록이 어떻게 동작하는지 관찰한다.
- [ ] 각 셀에 `@State`를 하나 두고, 배열 중간 원소를 삭제했을 때 남은 셀들의 상태가 유지되는지 확인한다.
- [ ] `String` 배열 대신 `Identifiable`을 따르는 `Photo` 구조체 배열로 바꿔 `id:` 없이 쓰는 형태로 고쳐 본다.
- [ ] `s[keyPath: \.self]`를 playground에서 실행해 identity key path가 값 전체를 가리키는 것을 확인한다.

## 참고 자료

- [Apple: ForEach](https://developer.apple.com/documentation/swiftui/foreach)
- [Apple: ForEach.init(_:id:content:)](https://developer.apple.com/documentation/swiftui/foreach/init(_:id:content:))
- [Apple: View.id(_:)](https://developer.apple.com/documentation/swiftui/view/id(_:))
- [Apple: Identifiable](https://developer.apple.com/documentation/swift/identifiable)
- [Apple: KeyPath](https://developer.apple.com/documentation/swift/keypath)
- [Apple: Hashable](https://developer.apple.com/documentation/swift/hashable)
- [The Swift Programming Language: Expressions — Key-Path Expression](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/expressions/)
