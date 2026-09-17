# `let`과 `var`

## 질문이 나온 코드

`chapter-11/chapter-11/ContentView.swift`의 `@Binding var value`, `let name`, `let color`

## 공부할 내용

- `let`은 값을 한 번 설정한 뒤 binding을 다른 값으로 바꿀 수 없는 상수를 선언한다.
- `var`는 같은 타입의 다른 값으로 다시 설정할 수 있는 변수를 선언한다.
- 바뀌지 않는 값은 우선 `let`으로 선언하고 변경이 필요할 때 `var`를 사용한다.
- `let`으로 선언한 struct 값의 variable property는 직접 바꿀 수 없다.
- `let`으로 선언한 class 참조는 다른 인스턴스를 가리킬 수 없지만, class가 허용하면 인스턴스 내부 상태는 바꿀 수 있다.
- `var`에는 stored property뿐 아니라 getter/setter로 계산되는 computed property도 있다.
- `@Binding var value`는 변경 가능한 wrapped value를 제공하므로 `var`로 선언한다. `name`과 `color`는 `SliderView` 내부에서 바뀌지 않으므로 `let`이 적합하다.

## 학습 체크리스트

- [ ] 지역 변수와 stored property에서 `let`/`var`를 비교한다.
- [ ] `let` struct와 `let` class의 property 변경 결과를 비교한다.
- [ ] stored property와 computed property를 각각 작성한다.

## 참고 자료

- [The Swift Programming Language: The Basics — Constants and Variables](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/)
- [The Swift Programming Language: Declarations](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/declarations/)
- [The Swift Programming Language: Properties](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/properties/)
