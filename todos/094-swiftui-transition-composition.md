# SwiftUI `transition`의 효과와 조합 방법

## 질문이 나온 코드

`chapter-104/chapter-104/ContentView.swift`

```swift
if let playerMove = viewModel.playerMove,
   let opponentMove = viewModel.opponentMove {
    Text("You choose: \(playerMove.rawValue)")
        .transition(.scale.combined(with: .opacity))

    Button("Play again") {
        withAnimation {
            viewModel.resetGame()
        }
    }
    .transition(.move(edge: .bottom).combined(with: .opacity))
}
```

## 공부할 내용

### `transition`은 뷰가 삽입되거나 제거될 때의 변화다

`transition(_:)`은 조건문 때문에 뷰가 계층에 **들어오거나 나갈 때** 어떤 시각적 변화를 사용할지 지정한다. 이미 화면에 남아 있는 뷰의 색상, 크기, 위치 같은 속성만 바뀌는 경우에는 transition이 아니라 일반 animation이 적용된다.

```swift
if isPresented {
    Text("Result")
        .transition(.opacity)
}
```

transition은 변화의 모양을 정의하고, 실제로 중간 프레임을 애니메이션하려면 삽입·제거를 일으키는 상태 변경이 animation transaction 안에서 발생해야 한다.

```swift
withAnimation(.easeInOut) {
    isPresented.toggle()
}
```

animation 없이 상태만 바꾸면 transition의 시작·끝 상태가 즉시 반영되어 효과를 보기 어렵다.

### `.scale`과 `.opacity`

코드에 사용된 이름은 `.scaled`가 아니라 **`.scale`** 이다.

- `.scale`: 뷰가 작은 배율에서 원래 배율로 커지며 삽입되고, 제거될 때 반대로 작아진다.
- `.opacity`: 투명도 0에서 1로 나타나고, 제거될 때 1에서 0으로 사라진다.

`scale(scale:anchor:)`를 사용하면 시작 배율과 기준점을 조절할 수 있다.

```swift
.transition(.scale(scale: 0.2, anchor: .bottomTrailing))
```

이것은 계속 유지되는 뷰의 크기를 바꾸는 `scaleEffect(_:)`와 목적이 다르다.

```swift
// 유지 중인 뷰의 상태 기반 크기 변화
.scaleEffect(isSelected ? 1.2 : 1)
.animation(.spring, value: isSelected)
```

### `combined(with:)`는 두 효과를 동시에 적용한다

```swift
.transition(.scale.combined(with: .opacity))
```

이 표현은 scale이 끝난 뒤 opacity를 실행한다는 뜻이 아니다. 삽입·제거 구간 동안 **크기와 투명도 변화를 함께** 적용한다.

```text
삽입 시작              삽입 완료
scale:   작음   ─────→ 원래 크기
opacity: 0      ─────→ 1
```

`combined(with:)`는 여러 transition을 한 효과로 합성하므로 다음처럼 이동과 페이드도 동시에 적용할 수 있다.

```swift
.transition(.move(edge: .bottom).combined(with: .opacity))
```

### 기본 transition 예시

```swift
.transition(.opacity)                  // 페이드
.transition(.scale)                    // 확대·축소
.transition(.move(edge: .leading))     // 지정한 가장자리에서 이동
.transition(.slide)                    // 슬라이드
.transition(.offset(x: 0, y: 100))     // 지정한 오프셋에서 이동
.transition(.identity)                 // 시각적 변화 없음
```

효과마다 적합한 쓰임이 다르다.

- 짧은 결과 메시지: `.opacity`
- 카드나 배지: `.scale.combined(with: .opacity)`
- 화면 아래에서 올라오는 작업 영역: `.move(edge: .bottom)`
- 목록 행 삽입·삭제: `.move(edge: .leading).combined(with: .opacity)`

### 삽입과 제거에 다른 효과 주기

`asymmetric(insertion:removal:)`을 사용하면 등장과 퇴장 효과를 다르게 지정할 수 있다.

```swift
.transition(
    .asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .scale.combined(with: .opacity)
    )
)
```

```text
삽입: 오른쪽에서 이동 + 페이드 인
제거: 축소 + 페이드 아웃
```

`combined(with:)`은 같은 구간에 여러 효과를 합치고, `asymmetric`은 삽입과 제거라는 서로 다른 구간에 별도 효과를 배치한다.

### 커스텀 modifier transition

기본 효과로 부족하면 `modifier(active:identity:)`로 전환 전후 modifier를 직접 정의할 수 있다. 두 modifier는 같은 타입이어야 한다.

```swift
struct BlurAndScale: ViewModifier {
    let blur: CGFloat
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .blur(radius: blur)
            .scaleEffect(scale)
    }
}

let blurTransition = AnyTransition.modifier(
    active: BlurAndScale(blur: 10, scale: 0.8),
    identity: BlurAndScale(blur: 0, scale: 1)
)
```

```swift
Text("Custom")
    .transition(blurTransition)
```

### 현재 코드에서 transition이 동작하는 이유

게임을 시작하면 `playerMove`와 `opponentMove`가 `nil`에서 값으로 바뀌어 `else`의 선택 버튼들이 제거되고 결과 `VStack`이 삽입된다. `viewModel.play(move)`가 `withAnimation` 안에서 실행되므로 두 분기의 제거와 삽입이 애니메이션된다.

`Play again`을 누르면 반대로 두 값이 `nil`이 되어 결과 화면이 제거되고 선택 버튼들이 다시 삽입된다. 이 상태 변경도 `withAnimation` 안에 있으므로 결과 텍스트와 버튼에 지정한 transition을 확인할 수 있다.

주의할 점은 같은 조건 분기 안에 있는 여러 자식에게 transition을 각각 붙였을 때 부모 레이아웃 변화와 자식 전환이 함께 일어난다는 것이다. 전체 결과 영역을 하나의 단위로 움직이고 싶다면 자식마다 붙이기보다 조건부 `VStack`에 transition 하나를 붙이는 편이 의도가 선명하다.

## 체크리스트

- [ ] `withAnimation`을 제거해 transition이 즉시 반영되는 모습을 비교한다.
- [ ] `.scale`, `.opacity`, `.move`, `.slide`, `.offset`을 하나씩 적용한다.
- [ ] `.scale.combined(with: .opacity)`에서 두 효과가 동시에 진행됨을 확인한다.
- [ ] `asymmetric`으로 삽입과 제거에 다른 효과를 준다.
- [ ] 자식별 transition과 결과 `VStack` 전체 transition의 차이를 비교한다.
- [ ] `scaleEffect`와 `.transition(.scale)`이 각각 상태 변경과 삽입·제거 중 무엇을 다루는지 설명한다.
- [ ] `modifier(active:identity:)`로 커스텀 transition을 만든다.

## 공식 참고 자료

- [Apple: View.transition(_:)](https://developer.apple.com/documentation/swiftui/view/transition(_:))
- [Apple: AnyTransition](https://developer.apple.com/documentation/swiftui/anytransition)
- [Apple: AnyTransition.scale](https://developer.apple.com/documentation/swiftui/anytransition/scale)
- [Apple: AnyTransition.opacity](https://developer.apple.com/documentation/swiftui/anytransition/opacity)
- [Apple: AnyTransition.combined(with:)](https://developer.apple.com/documentation/swiftui/anytransition/combined(with:))
- [Apple: AnyTransition.asymmetric(insertion:removal:)](https://developer.apple.com/documentation/swiftui/anytransition/asymmetric(insertion:removal:))
- [Apple: Animating views and transitions](https://developer.apple.com/tutorials/swiftui/animating-views-and-transitions)
