# `id`에 쓰이는 `Hashable`과 해시 충돌 걱정

`id: \.self`가 무엇을 가리키는지는 [`ForEach`의 `id`와 `\.self` key path](./foreach-id-and-identity-keypath.md)에, `Identifiable`을 쓰는 이유는 [`Identifiable` 프로토콜을 쓰는 이유와 쓰는 경우](./identifiable-protocol.md)에 있다. 이 문서는 **`Hashable` 요구사항과 값이 같을 때 생기는 문제**를 다룬다.

## 질문이 나온 코드

`chapter-32/chapter-32/ContentView.swift`의 `struct Todo: Identifiable, Hashable`과 `ForEach($todos, id: \.self)`

## 공부할 내용

### `id`는 `Hashable`이어야 한다 — 상속이 아니라 준수다

`ForEach(_:id:)`의 `id`로 지목한 값의 타입은 `Hashable`을 준수해야 한다. `\.self`를 썼다면 **원소 타입 전체**가 그 대상이므로 `Todo`가 `Hashable`이어야 한다. 코드에 `: Identifiable, Hashable`이 붙어 있는 이유다.

`Hashable`은 `Equatable`을 상속한 protocol이다.

> `protocol Hashable : Equatable`
>
> "The `Hashable` protocol inherits from the `Equatable` protocol, so you must also satisfy that protocol's requirements."

즉 `Hashable`을 붙이면 "해시를 낼 수 있다"와 "두 값이 같은지 비교할 수 있다"를 동시에 얻는다. SwiftUI가 목록을 대조할 때 실제로 쓰는 것은 이 둘이다.

직접 구현할 일은 거의 없다. 저장 프로퍼티가 전부 `Hashable`이면 컴파일러가 만들어 준다.

> "For structs whose stored properties are all `Hashable`, ... the compiler is able to provide an implementation of `hash(into:)` automatically."

`Todo`의 `UUID`, `String`, `Bool`이 모두 `Hashable`이라 `: Hashable`만 적으면 끝난다.

### "모든 필드 값이 같으면 해시도 같나" — 그렇다

이것이 `Hashable`의 규약 자체다.

> "Two instances that are equal must feed the same values to `Hasher` in `hash(into:)`, in the same order."
>
> "Hashing a value means feeding its essential components into a hash function... Essential components are those that contribute to the type's implementation of `Equatable`."

컴파일러가 만들어 준 구현은 **모든 저장 프로퍼티**를 essential component로 본다. 그래서 모든 필드가 같으면 `==`가 참이고 해시도 반드시 같다. 반대 방향은 보장되지 않는다(해시가 같아도 값이 다를 수 있다 — 이것이 해시 충돌이다).

### "그러면 버그가 생기나" — 충돌 때문은 아니고, **값 중복** 때문이다

걱정하신 방향과 실제 위험은 조금 다르다.

**해시 충돌 자체는 문제가 아니다.** 서로 다른 두 값이 우연히 같은 해시를 가져도, 최종 판단은 `==`가 한다. `Set`이나 `Dictionary`도 그렇게 동작한다. 해시는 후보를 좁히는 용도일 뿐이다.

**진짜 위험은 `==`까지 같은, 즉 완전히 동일한 값이 배열에 두 개 있는 경우다.** `id: \.self`는 값 자체를 신원으로 삼으므로, 같은 값이 둘이면 신원이 겹쳐 SwiftUI가 두 행을 구분하지 못한다.

지금 코드는 안전하다. `Todo`에 `let id = UUID()`가 있고 `UUID()`는 인스턴스마다 새로 발급되므로, `title`과 `completed`가 똑같아도 `id`가 달라 두 값은 결코 같아지지 않는다. 실제로 "Buy groceries"를 두 번 추가해도 문제가 없다. 만약 `id` 필드가 없었다면 같은 제목을 두 번 추가하는 순간 신원이 겹친다.

### 다만 이 코드에는 다른 문제가 있다 — 신원이 흔들린다

`id: \.self`는 **값 전체**를 신원으로 쓴다. `Todo`의 값에는 `completed`도 포함돼 있다. 따라서 체크박스를 눌러 `completed`가 `false → true`가 되면 **그 항목의 신원이 바뀐다.** SwiftUI 입장에서는 기존 항목이 사라지고 새 항목이 나타난 것과 같다.

`Hasher` 문서가 이 점을 분명히 한다.

> "the underlying hash algorithm is designed to exhibit avalanche effects: slight changes to the seed or the input byte sequence will typically produce drastic changes in the generated hash value."

해결은 간단하다. `Todo`는 이미 `Identifiable`이므로 **`id:`를 빼면 된다.**

```swift
ForEach($todos) { $todo in ... }   // UUID를 신원으로 사용 — 값이 바뀌어도 신원 유지
```

이렇게 하면 신원이 `UUID` 하나에만 달려 있어 `completed`를 토글해도 흔들리지 않는다. 행마다 상태나 애니메이션을 붙이는 순간 차이가 드러난다.

정리하면 **`Identifiable`을 이미 붙였다면 `id: \.self`는 쓰지 않는 편이 맞다.** `\.self`는 `String` 배열처럼 신원으로 쓸 필드가 따로 없을 때의 수단이다.

### 해시 값을 저장하면 안 된다

> "Hash values are not guaranteed to be equal across different executions of your program. Do not save hash values to use during a future execution."

Swift의 해시는 실행마다 시드가 달라진다. 해시 값을 파일이나 서버에 저장해 두고 다음 실행에서 비교하는 식으로 쓰면 안 된다.

## 학습 체크리스트

- [ ] `Todo`에서 `Hashable`을 빼고 `id: \.self`를 유지했을 때 어떤 컴파일 오류가 나는지 읽는다.
- [ ] 같은 제목의 할 일을 두 번 추가해 보고, `id = UUID()` 덕분에 문제가 없음을 확인한다.
- [ ] `Todo`에서 `let id = UUID()`를 지운 뒤 같은 제목을 두 번 추가해 신원이 겹칠 때의 동작을 관찰한다.
- [ ] `ForEach($todos, id: \.self)`를 `ForEach($todos)`로 바꾸고, 체크박스를 눌렀을 때 동작 차이를 비교한다.
- [ ] 각 행에 `@State`를 가진 하위 뷰를 넣고, `id: \.self`일 때 체크박스를 누르면 그 상태가 초기화되는지 확인한다.
- [ ] `print(todo.hashValue)`를 앱을 두 번 실행해 찍어 보고 값이 달라지는 것을 확인한다.
- [ ] `Todo` 두 개를 만들어 모든 필드를 같게 맞춘 뒤 `==`와 `hashValue`를 비교한다.
- [ ] `hash(into:)`를 직접 구현해 `id`만 combine 하도록 바꾸고 결과가 어떻게 달라지는지 본다.

## 참고 자료

- [Apple: Hashable](https://developer.apple.com/documentation/swift/hashable)
- [Apple: Equatable](https://developer.apple.com/documentation/swift/equatable)
- [Apple: Hasher](https://developer.apple.com/documentation/swift/hasher)
- [Apple: Hashable.hashValue](https://developer.apple.com/documentation/swift/hashable/hashvalue)
- [Apple: Identifiable](https://developer.apple.com/documentation/swift/identifiable)
- [Apple: ForEach.init(_:id:content:)](https://developer.apple.com/documentation/swiftui/foreach/init(_:id:content:))
- [Apple: ForEach](https://developer.apple.com/documentation/swiftui/foreach)
- [Apple: UUID](https://developer.apple.com/documentation/foundation/uuid)
