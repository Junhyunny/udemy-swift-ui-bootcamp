# Swift 접근 제어

## 질문이 나온 코드

`chapter-11/chapter-11/ContentView.swift`의 `@State private var red`와 접근 제어자를 생략한 `@Binding var value`

## 공부할 내용

- `private`: 둘러싼 선언과 같은 파일에 있는 해당 선언의 extension 내부에서 접근
- `fileprivate`: 선언된 source file 내부에서 접근
- `internal`: 같은 module 내부에서 접근하며, 대부분 선언의 기본 접근 수준
- `package`: 같은 package에 속한 module에서 접근
- `public`: 다른 module에서도 접근하지만 외부 subclass와 override는 제한
- `open`: class와 class member에만 적용되며 다른 module에서 subclass와 override도 허용
- 더 공개된 선언은 자신보다 덜 공개된 타입을 parameter나 return type으로 노출할 수 없다.
- 단일 app target에서는 기본 `internal`이 대체로 충분하고, 구현 세부 사항을 숨길 때 `private` 또는 `fileprivate`를 사용한다.

## 학습 체크리스트

- [ ] 여섯 접근 수준을 공개 범위 순서대로 설명한다.
- [ ] `private`와 `fileprivate`를 서로 다른 extension과 source file에서 비교한다.
- [ ] `public`과 `open`의 차이를 class 상속 예제로 확인한다.
- [ ] `@testable import`가 test target에 internal 선언을 노출하는 방식을 확인한다.

## 참고 자료

- [The Swift Programming Language: Access Control](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/accesscontrol/)
- [The Swift Programming Language: Declarations](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/declarations/)
- [The Swift Programming Language: Attributes (`@testable`)](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/attributes/)
