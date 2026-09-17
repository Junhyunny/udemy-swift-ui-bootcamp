# `animation(_:value:)`의 `value`가 필요한 이유

## 질문이 나온 코드

`chapter-41/chapter-41/ContentView.swift`의 다음 코드다.

```swift
.offset(y: flag ? 400 : 0)
.animation(.easeInOut(duration: 2), value: flag)
```

## 공부할 내용

### `value`는 애니메이션할 값을 넘기는 인자가 아니다

`animation(_:value:)`의 `value`는 SwiftUI가 **변화를 감시할 트리거**다. 공식 시그니처에서 `V`가 `Equatable`이어야 하는 것도 이전 값과 새 값을 비교해야 하기 때문이다.

```swift
func animation<V>(
    _ animation: Animation?,
    value: V
) -> some View where V: Equatable
```

`flag`가 바뀌면 SwiftUI는 `body`를 다시 계산한다. 그 결과 `offset`이 `0`에서 `400`으로 달라지고, `offset`처럼 보간할 수 있는 값은 지정한 곡선을 따라 중간값을 그리며 이동한다. `animation`이 `flag`를 내부에서 바꾸는 것은 아니다.

흐름을 나누면 다음과 같다.

1. 버튼이 `flag.toggle()`을 실행한다.
2. SwiftUI가 `flag` 변경을 감지해 뷰를 다시 계산한다.
3. `animation(_:value:)`도 감시하던 `flag`가 달라졌음을 확인한다.
4. modifier가 붙은 뷰 아래에서 함께 달라진 애니메이션 가능한 값에 해당 애니메이션을 적용한다.

즉 `flag`는 **언제 애니메이션할지**를 정하고, `offset(y:)`의 이전 값과 새 값은 **무엇을 보간할지**를 정한다.

### 왜 트리거를 명시해야 하는가

예전의 `animation(_:)`는 뷰에서 어떤 애니메이션 가능한 값이 달라져도 넓게 적용되어 의도하지 않은 변화까지 움직이기 쉬웠다. `value`를 명시하면 적어도 "이 값이 바뀐 업데이트에서 애니메이션한다"는 조건을 표현할 수 있다.

다만 `value`와 애니메이션 대상이 일대일로 묶이는 것은 아니다. `flag`가 바뀌는 같은 렌더링 사이클에 modifier 아래의 `opacity`, `scale`, `offset`이 함께 달라지면 모두 같은 애니메이션을 받을 수 있다. 특정 modifier 하나만 정확히 한정하고 싶다면 최신 SwiftUI의 `animation(_:body:)`처럼 애니메이션할 modifier를 클로저 안에 두는 방법도 있다.

```swift
RoundedRectangle(cornerRadius: 20)
    .animation(.easeInOut) { content in
        content.offset(y: flag ? 400 : 0)
    }
```

### 감시값은 무엇을 골라야 하는가

뷰의 시각적 변화를 실제로 유발하는 상태를 고른다.

```swift
// isExpanded가 바뀔 때 frame 변화를 애니메이션한다.
.frame(height: isExpanded ? 300 : 100)
.animation(.spring, value: isExpanded)
```

여러 상태의 조합이 한 애니메이션의 트리거라면 작은 `Equatable` 값이나 구조체로 묶을 수 있다. 관계없는 값을 넣으면 필요한 때 애니메이션이 실행되지 않거나, 반대로 관계없는 변경에도 실행되어 코드의 의도가 흐려진다.

## 학습 체크리스트

- [ ] `flag`를 토글하며 `offset`이 이전 값과 새 값 사이를 보간하는지 확인한다.
- [ ] `value: flag`를 제거했을 때 이동이 즉시 일어나는지 비교한다.
- [ ] 별도의 `@State`로 `opacity`를 추가하고 `flag`와 같은 업데이트에서 바꿔 적용 범위를 확인한다.
- [ ] `animation(_:body:)` 안에 `offset`만 넣어 다른 변화와 범위가 분리되는지 확인한다.
- [ ] `value`가 `Equatable`이어야 하는 이유를 이전 값과 새 값 비교 관점에서 설명한다.

## 공식 참고 자료

- [Apple: animation(_:value:)](https://developer.apple.com/documentation/swiftui/view/animation(_:value:))
- [Apple: animation(_:body:)](https://developer.apple.com/documentation/swiftui/view/animation(_:body:))
- [Apple: Animation](https://developer.apple.com/documentation/swiftui/animation)
- [Apple: Animations](https://developer.apple.com/documentation/swiftui/animations)
