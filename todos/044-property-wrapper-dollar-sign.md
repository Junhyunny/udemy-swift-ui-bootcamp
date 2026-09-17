# 프로퍼티 래퍼의 `$` 사용 기준

## 질문이 나온 코드

`chapter-11/chapter-11/ContentView.swift`의 `Slider(value: $value)`와 `Text(... value)`

## 공부할 내용

- 프로퍼티 래퍼가 적용된 이름을 그대로 쓰면 `wrappedValue`에 접근한다.
- 이름 앞에 `$`를 붙이면 래퍼가 제공하는 `projectedValue`에 접근한다.
- `$`의 결과 타입은 항상 같지 않고 각 프로퍼티 래퍼가 정의한다. SwiftUI의 `@State`와 `@Binding`은 projected value로 `Binding<Value>`를 제공한다.
- `Binding`은 값을 직접 저장하지 않고 다른 source of truth를 읽고 쓸 수 있게 연결한다.
- API가 일반 값 `Double`을 요구하면 `value`를, 양방향 연결인 `Binding<Double>`을 요구하면 `$value`를 전달한다.
- 현재 코드에서 `Text`는 표시할 현재 값이 필요하므로 `value`를 읽고, `Slider`는 사용자 조작으로 값을 변경해야 하므로 `$value`를 받는다.
- `$0`, `$1`은 이름을 생략한 closure parameter이므로 프로퍼티 래퍼의 `$property`와는 별개다.

## 학습 체크리스트

- [ ] `wrappedValue`와 `projectedValue`의 차이를 설명한다.
- [ ] `@State`의 `$red`와 `@Binding`의 `$value` 타입을 compiler 또는 Quick Help로 확인한다.
- [ ] `Slider(value: value)`와 `Text("\($value)")`를 각각 시도하고 type error를 읽는다.
- [ ] 간단한 custom property wrapper에 `projectedValue`를 정의해 `$프로퍼티명`으로 사용한다.

## 참고 자료

- [Apple: Binding](https://developer.apple.com/documentation/swiftui/binding)
- [Apple: State.projectedValue](https://developer.apple.com/documentation/swiftui/state/projectedvalue)
- [Apple: Managing user interface state](https://developer.apple.com/documentation/swiftui/managing-user-interface-state)
- [The Swift Programming Language: Properties — Property Wrappers](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/properties/)
