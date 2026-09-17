# 여러 `offset` modifier는 어떻게 합성되는가

## 질문이 나온 코드

`chapter-42/chapter-42/ContentView.swift`의 앞면 이미지에 `offset`이 두 번 적용되어 있다.

```swift
Image(.cfgdFront)
    .offset(y: 20)
    .offset(
        x: valueTranslation.width / 30,
        y: valueTranslation.height / 30
    )
```

## 공부할 내용

### 이 코드에서는 두 이동량이 더해진다

`offset(x:y:)`는 뷰의 표시 내용을 지정한 가로·세로 거리만큼 옮긴다. 위 코드처럼 순수한 평행 이동을 연속 적용하면 최종 이동량은 다음과 같다.

```swift
x = valueTranslation.width / 30
y = 20 + valueTranslation.height / 30
```

따라서 한 번에 작성해도 현재 화면 결과는 같다.

```swift
.offset(
    x: valueTranslation.width / 30,
    y: 20 + valueTranslation.height / 30
)
```

두 번째 `offset`이 첫 번째 값을 덮어쓰는 것이 아니라, 첫 번째 modifier가 만든 뷰를 두 번째 modifier가 다시 이동시킨다. SwiftUI modifier는 앞 단계의 결과를 차례로 감싸기 때문이다.

### 나눠 쓰는 이유는 계산보다 의미에 있다

현재 두 값의 역할은 서로 다르다.

- `.offset(y: 20)`은 카드 앞면의 고정된 기본 위치다.
- 두 번째 `offset`은 드래그 중에만 달라지는 시차(parallax) 이동이다.

이처럼 **기본 배치**와 **상호작용에 따른 변화량**을 분리하면 각 값의 출처와 수정 이유가 잘 보인다. SwiftUI에서 modifier를 조합해 효과를 표현하는 것은 일반적인 방식이다. 반대로 두 값이 같은 개념이고 항상 함께 바뀐다면 한 번에 합치는 편이 더 단순하다.

재사용할 의미가 있다면 이름을 붙이는 방법도 있다.

```swift
private let frontBaseOffset = CGSize(width: 0, height: 20)

private var dragOffset: CGSize {
    CGSize(
        width: valueTranslation.width / 30,
        height: valueTranslation.height / 30
    )
}

// 사용 위치
.offset(frontBaseOffset)
.offset(dragOffset)
```

### 모든 modifier가 단순히 더해지는 것은 아니다

Apple 문서는 modifier를 연결할 때 각각이 이전 결과를 감싸며, 적용 순서가 중요하다고 설명한다. 두 `offset`처럼 같은 좌표계의 평행 이동끼리는 더한 것과 같은 결과가 나오지만, `rotationEffect`, `scaleEffect`, `frame`, `background`, `clipped` 등을 섞으면 순서를 바꿨을 때 결과가 달라질 수 있다.

```swift
// 이동한 결과를 회전
card
    .offset(x: 80)
    .rotationEffect(.degrees(30))

// 회전한 결과를 화면의 x축으로 이동
card
    .rotationEffect(.degrees(30))
    .offset(x: 80)
```

modifier 목록은 위에서 아래로 읽되, 각 줄이 바로 앞에서 만들어진 뷰를 다시 감싼다고 생각하면 된다.

### `offset`은 주변 레이아웃을 다시 배치하지 않는다

Apple의 `offset` 문서에서 중요한 점은 표시 내용만 옮기고 원래 뷰의 크기는 바꾸지 않는다는 것이다. 스택은 여전히 이동 전 위치에 공간을 예약한다. 그래서 큰 `offset`을 배치 도구처럼 사용하면 다른 뷰와 겹치거나 터치·경계 판단이 직관적이지 않을 수 있다.

- 작은 시각 보정, 드래그, 애니메이션, 시차 효과에는 `offset`이 잘 맞는다.
- 주변 뷰도 함께 밀어야 하는 간격은 `padding`, 스택의 `spacing`, 정렬 같은 레이아웃 도구를 우선한다.
- 부모 좌표에서 중심점을 직접 지정하려면 `position`을 검토한다.

## 학습 체크리스트

- [ ] 현재의 두 `offset`을 하나로 합쳐 화면 결과가 같은지 확인한다.
- [ ] 각 `offset` 뒤에 서로 다른 색의 `border`를 붙여 modifier가 감싸지는 단계를 관찰한다.
- [ ] `offset`과 `rotationEffect`의 순서를 바꾸고 결과를 비교한다.
- [ ] `VStack`의 한 자식에 큰 `offset`을 주고 다른 자식의 원래 배치가 유지되는지 확인한다.
- [ ] 고정 위치와 드래그 변화량을 분리할 때 얻는 가독성 이점을 설명한다.
- [ ] 시각 효과에는 `offset`, 실제 간격 조정에는 `padding`을 선택하는 이유를 설명한다.

## 공식 참고 자료

- [Apple: View.offset(x:y:)](https://developer.apple.com/documentation/swiftui/view/offset(x:y:))
- [Apple: Configuring views](https://developer.apple.com/documentation/swiftui/configuring-views)
- [Apple: Layout modifiers](https://developer.apple.com/documentation/swiftui/view-layout)
- [Apple: Making fine adjustments to a view's position](https://developer.apple.com/documentation/swiftui/making-fine-adjustments-to-a-view-s-position)
- [Apple: SwiftUI essentials](https://developer.apple.com/videos/play/wwdc2024/10150/)
