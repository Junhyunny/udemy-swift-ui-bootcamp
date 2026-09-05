# Combine 프레임워크

## 질문이 나온 코드

`chapter-09/chapter-09/ContentView.swift`의 `internal import Combine`, `ObservableObject`, `@Published`

## 공부할 내용

- Combine은 시간에 따라 발생하는 값을 선언적으로 처리하는 Apple 프레임워크다.
- `Publisher`는 값을 내보내고 `Subscriber`는 값을 받는다.
- `ObservableObject`는 객체가 변경되기 전에 이벤트를 보내는 `objectWillChange` publisher를 제공한다.
- `@Published`를 붙인 프로퍼티는 변경 이벤트를 발행하며 `$프로퍼티명`으로 해당 publisher에 접근할 수 있다.
- 현재 코드에서는 SwiftUI가 `StopWatchViewModel.objectWillChange`를 관찰하고 `elapsedTime` 변경 시 관련 View를 갱신한다.

## 학습 체크리스트

- [ ] Publisher와 Subscriber의 역할을 설명한다.
- [ ] `ObservableObject`와 `@Published`의 관계를 설명한다.
- [ ] `$elapsedTime`을 구독해 값 변경을 로그로 확인한다.
- [ ] 구독 취소를 담당하는 `Cancellable`과 `AnyCancellable`을 확인한다.

## 참고 자료

- [Apple: Combine](https://developer.apple.com/documentation/combine)
- [Apple: ObservableObject](https://developer.apple.com/documentation/combine/observableobject)
- [Apple: Published](https://developer.apple.com/documentation/combine/published)
