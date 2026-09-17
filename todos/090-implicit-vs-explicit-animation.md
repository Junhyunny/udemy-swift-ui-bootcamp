# 암시적 애니메이션과 `withAnimation`의 차이

## 질문이 나온 코드

`chapter-41/chapter-41/ContentView.swift`에는 뷰에 붙이는 방식과 상태 변경을 감싸는 방식이 함께 비교되어 있다.

```swift
// 뷰에 애니메이션 규칙을 선언
.animation(.easeInOut(duration: 2), value: flag)

// 특정 동작의 상태 변경에 애니메이션을 적용
withAnimation(.bouncy().repeatCount(3, autoreverses: true)) {
    flag.toggle()
}
```

## 공부할 내용

### 공통점: 상태 변화 전후의 뷰를 보간한다

두 방식 모두 뷰를 직접 프레임마다 움직이는 명령은 아니다. 상태가 바뀌면 SwiftUI가 새 뷰 값을 계산하고, 이전 값과 새 값 사이에서 애니메이션 가능한 속성을 보간한다. 차이는 **애니메이션을 어떤 범위와 계기로 트랜잭션에 넣는가**에 있다.

### `animation(_:value:)`: 뷰에 규칙을 붙인다

```swift
Box(isExpanded: isExpanded)
    .animation(.spring, value: isExpanded)
```

감시하는 값이 달라질 때 해당 modifier가 붙은 뷰 범위에 애니메이션을 적용한다. 상태를 어디에서 바꾸든 이 뷰는 같은 규칙을 사용한다.

이 방식이 잘 맞는 경우는 다음과 같다.

- 특정 뷰의 특정 상태 변화가 항상 같은 방식으로 움직여야 할 때
- 상태 변경 코드와 애니메이션 표현을 분리하고 싶을 때
- 넓은 화면이 아니라 modifier가 붙은 뷰 쪽으로 범위를 제한하고 싶을 때

### `withAnimation`: 상태 변경 동작을 감싼다

```swift
withAnimation(.spring) {
    isExpanded.toggle()
}
```

Apple 문서에 따르면 `withAnimation`은 현재 `Transaction`의 `animation` 프로퍼티를 설정한 상태에서 클로저를 실행한다. 따라서 클로저 안의 상태 변경으로 다시 계산되는 뷰들 중 그 트랜잭션을 전달받는 애니메이션 가능한 변화가 함께 움직인다. 변경 대상 뷰가 `withAnimation`을 호출한 코드보다 상위 계층에 있어도 영향을 받을 수 있다.

이 방식이 잘 맞는 경우는 다음과 같다.

- 탭, 저장 완료, 항목 추가·삭제처럼 **특정 사용자 동작**의 결과 전체를 함께 움직일 때
- 같은 상태라도 변경 경로에 따라 애니메이션 여부나 곡선을 다르게 할 때
- 여러 상태 변경을 하나의 애니메이션 트랜잭션으로 묶을 때
- 완료 콜백이 필요한 애니메이션을 시작할 때

예를 들어 같은 `isExpanded` 변경이라도 버튼 탭은 애니메이션하고 초기 데이터 복원은 즉시 반영할 수 있다.

```swift
Button("펼치기") {
    withAnimation(.spring) {
        isExpanded.toggle()
    }
}

func restoreState() {
    isExpanded = savedValue // 애니메이션 없이 반영
}
```

### 적용 범위가 가장 중요한 차이

| 구분 | `animation(_:value:)` | `withAnimation` |
| --- | --- | --- |
| 선언 위치 | 움직일 뷰 쪽 | 상태를 바꾸는 동작 쪽 |
| 시작 조건 | 지정한 `Equatable` 값의 변경 | 클로저 안에서 발생한 상태 변경 |
| 의도 | 이 뷰의 변화 규칙 | 이 동작의 변화 규칙 |
| 범위 조절 | modifier가 붙은 뷰 계층으로 제한 | 같은 트랜잭션을 받는 관련 뷰 변화에 전달 |
| 변경 경로별 차등 | 불편함 | 자연스러움 |

둘을 동시에 적용하면 뷰에 더 가까운 트랜잭션 수정이 결과에 영향을 줄 수 있어 이해하기 어려워진다. 같은 변화에는 우선 한 방식을 선택하고, 여러 애니메이션 규칙이 필요하면 뷰 계층과 modifier 위치를 명확히 나누는 편이 좋다.

## 학습 체크리스트

- [ ] 같은 `flag.toggle()`을 `animation(_:value:)`와 `withAnimation`으로 각각 구현해 결과를 비교한다.
- [ ] 버튼 탭에는 `withAnimation`을 쓰고 별도 버튼에서는 애니메이션 없이 같은 상태를 바꿔 차이를 확인한다.
- [ ] 하나의 `withAnimation` 안에서 두 `@State` 값을 바꿔 두 뷰가 함께 움직이는지 확인한다.
- [ ] `animation(_:value:)`의 위치를 자식과 부모로 옮기며 적용 범위가 어떻게 달라지는지 확인한다.
- [ ] "뷰의 규칙"과 "동작의 규칙" 중 어떤 의도를 표현할지 기준으로 두 방식을 설명한다.

## 공식 참고 자료

- [Apple: Animations](https://developer.apple.com/documentation/swiftui/animations)
- [Apple: animation(_:value:)](https://developer.apple.com/documentation/swiftui/view/animation(_:value:))
- [Apple: withAnimation(_:_:)](https://developer.apple.com/documentation/swiftui/withanimation(_:_:))
- [Apple: Managing user interface state](https://developer.apple.com/documentation/swiftui/managing-user-interface-state)
- [Apple: withAnimation completion](https://developer.apple.com/documentation/swiftui/withanimation(_:completioncriteria:_:completion:))
- [Apple: Transaction](https://developer.apple.com/documentation/swiftui/transaction)
