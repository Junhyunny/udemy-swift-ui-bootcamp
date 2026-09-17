# `struct`와 `class`

## 질문이 나온 코드

`chapter-11/chapter-11/ContentView.swift`의 `ColorMixerApp: View`와 앞 장의 `ObservableObject` ViewModel

## 공부할 내용

- `struct`는 값 타입이다. 대입하거나 함수에 전달하면 독립된 값처럼 동작한다.
- `class`는 참조 타입이다. 여러 변수가 동일한 인스턴스와 identity를 공유할 수 있고 ARC로 수명을 관리한다.
- 둘 다 프로퍼티, 메서드, initializer, extension, protocol 채택을 지원한다.
- class만 상속, type casting, `deinit`, reference counting을 지원한다.
- SwiftUI의 `View`는 protocol이며 custom View는 보통 가벼운 값 타입인 struct로 선언한다. View 값은 UI의 영구 객체라기보다 현재 UI 구성을 표현한다.
- Combine의 `ObservableObject`는 `AnyObject`를 상속하는 class 전용 protocol이다. 공유되는 하나의 상태와 identity를 여러 View가 관찰하는 용도에 참조 타입이 맞는다.

## 학습 체크리스트

- [ ] value semantics와 reference semantics를 예제로 비교한다.
- [ ] class 인스턴스의 identity 비교 연산자 `===`를 실습한다.
- [ ] View struct가 다시 만들어져도 `@State` 값이 보존되는 이유를 확인한다.
- [ ] “View는 항상 struct여야 한다”와 “`ObservableObject`는 class여야 한다”의 정확성 차이를 설명한다.

## 참고 자료

- [The Swift Programming Language: Structures and Classes](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/classesandstructures/)
- [Apple: View](https://developer.apple.com/documentation/swiftui/view)
- [Apple: ObservableObject](https://developer.apple.com/documentation/combine/observableobject)
