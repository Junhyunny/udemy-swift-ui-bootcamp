# `scaledToFill()`이 레이아웃을 흔드는 이유와 `clipped()`가 해결하는 것

프리뷰의 파란 테두리와 `Image` 크기 modifier의 기초는 [별도 문서](./image-layout-and-preview-bounds.md)에 있다. 이 문서는 **실제로 겪은 증상**의 원인을 파고든다.

## 질문이 나온 코드

`chapter-56/chapter-56/ContentView.swift`

```swift
PhaseAnimator(photoCollection, trigger: animate) { imageResource in
    Image(imageResource)
        .resizable()
        .scaledToFill()
        .clipped()          // ← 이것을 넣었더니 개선되었다
        .ignoresSafeArea()
} animation: { _ in
    Animation.snappy(duration: 2)
}
```

**증상**: 사진이 전환될 때 이미지가 움직이거나 위치가 바뀌고, 애니메이션이 툭툭 끊겼다.

## 공부할 내용

### 문제의 출발점 — 사진들의 비율이 제각각이다

이 프로젝트의 에셋을 실제로 확인해 보면 이렇다.

```text
pic1  4000×4000  → 1 : 1.00   (정사각형)
pic2  4000×5000  → 1 : 1.25
pic3  3490×6017  → 1 : 1.72   ← 유독 길쭉하다
pic4  2939×3211  → 1 : 1.09
pic5  3041×4055  → 1 : 1.33
pic6  3024×4032  → 1 : 1.33
```

정사각형부터 세로로 긴 것까지 섞여 있다. 이 차이가 모든 문제의 근원이다.

### SwiftUI 레이아웃의 핵심 개념 — "레이아웃 크기"와 "그려지는 크기"는 다르다

이것을 이해하면 나머지가 다 풀린다. Apple 문서의 한 문장이 결정적이다.

> **By default, a view's bounding frame is used only for layout, so any content that extends beyond the edges of the frame is still visible.**

번역하면 이렇다. **프레임은 배치 계산에만 쓰이고, 그 밖으로 삐져나온 내용은 잘리지 않고 그대로 보인다.**

즉 뷰에는 두 가지 크기가 있다.

| | 의미 | 부모가 보는 값 |
| --- | --- | --- |
| **레이아웃 크기** | 부모에게 "나는 이만큼 차지한다"고 보고하는 크기 | O |
| **그려지는 크기** | 실제로 픽셀이 칠해지는 영역 | X |

기본적으로 SwiftUI는 이 둘이 달라도 내버려 둔다.

### `scaledToFill()`이 하는 일

```swift
nonisolated func scaledToFill() -> some View
```

> A view that scales this view to fill its parent, **maintaining this view's aspect ratio**.

핵심은 **비율을 유지한 채 부모를 채운다**는 것이다. `aspectRatio(nil, contentMode: .fill)`과 같다.

부모 영역이 정사각형이고 이미지가 세로로 길다면 이렇게 된다.

```text
부모 영역 (예: 400×400)
┌─────────────┐
│             │
│             │   ← 세로로 긴 이미지(1:1.72)를 fill하면
│             │      가로를 400에 맞추는 순간 세로는 688이 된다
│             │      → 위아래로 각각 144씩 넘친다
└─────────────┘
```

넘치는 양은 **이미지 비율에 따라 다르다.** pic1(정사각형)은 거의 안 넘치고, pic3(1:1.72)은 크게 넘친다.

`scaledToFit()`이었다면 반대로 **안쪽에 다 들어오게** 축소되어 여백이 생긴다. 넘침이 없으니 이 문제도 없다.

### 그래서 무슨 일이 벌어졌나

`clipped()`가 없을 때의 연쇄를 따라가 보자.

```text
① pic1(정사각형)이 표시된다
   → scaledToFill로 확대, 약간 넘침

② 탭 → PhaseAnimator가 다음 phase로
   → pic3(1:1.72)으로 교체
   → scaledToFill로 확대, 위아래로 크게 넘침

③ 넘친 부분이 잘리지 않고 그대로 그려진다
   → 그려지는 영역이 이전보다 훨씬 커진다

④ 레이아웃 시스템이 이 크기 변화를 감지
   → ZStack의 정렬이 다시 계산된다
   → 겹쳐 있는 Text의 위치도 영향을 받는다

⑤ PhaseAnimator가 이 레이아웃 변화까지 애니메이션한다
   → 사진이 스르륵 움직이고 위치가 바뀌는 것처럼 보인다
```

**"이미지가 움직인다"의 정체가 ⑤다.** 사진을 움직이라고 시킨 적이 없는데, 사진마다 차지하는 영역이 달라서 레이아웃이 매번 다시 잡히고, 그 과정이 애니메이션된 것이다.

**"툭툭 끊긴다"는 것도 여기서 온다.** 애니메이션되는 대상이 일정하지 않다. pic1→pic2 전환의 크기 변화와 pic2→pic3 전환의 크기 변화가 완전히 달라서, 매번 다른 폭으로 출렁인다. 게다가 `.snappy`는 스프링 계열이라 목표를 지나쳤다가 돌아오는 성질이 있어 흔들림이 더 두드러진다.

### `clipped()`가 해결한 것

```swift
nonisolated func clipped(antialiased: Bool = false) -> some View
```

> Use the `clipped(antialiased:)` modifier to **hide any content that extends beyond the layout bounds** of the shape.

**레이아웃 경계 밖으로 나간 내용을 잘라낸다.** 앞서 인용한 "기본적으로는 잘리지 않고 보인다"의 정반대 동작을 켜는 것이다.

이 한 줄이 넣어지는 순간 이렇게 바뀐다.

```text
clipped() 없음:  그려지는 크기 = 확대된 이미지 크기 (사진마다 다름)
clipped() 있음:  그려지는 크기 = 레이아웃 크기      (사진과 무관하게 일정)
```

**그려지는 영역이 사진 비율과 무관하게 고정되므로**, 전환할 때 레이아웃이 흔들릴 이유가 사라진다. PhaseAnimator가 애니메이션할 레이아웃 변화 자체가 없어지는 것이다.

핵심을 한 문장으로 하면 이렇다. **`clipped()`는 "그려지는 크기"를 "레이아웃 크기"에 맞춰 강제로 일치시킨다.**

### 왜 `scaledToFill` + `clipped`가 한 세트인가

이 조합이 관용구로 굳어진 이유가 여기 있다.

| 조합 | 결과 |
| --- | --- |
| `scaledToFit()` 단독 | 여백이 생기지만 넘침 없음. 안전하다 |
| `scaledToFill()` 단독 | 영역을 꽉 채우지만 **넘쳐서 주변을 침범** |
| `scaledToFill()` + `clipped()` | 꽉 채우고 넘친 부분은 잘림. **의도한 동작** |

사진을 배경으로 꽉 채우고 싶으면 `fill`이 필요하고, `fill`을 쓰면 반드시 `clipped()`가 따라와야 한다. 한쪽만 쓰면 위와 같은 문제가 생긴다.

### 순서가 중요하다

`clipped()`는 **자기 앞까지의 결과**를 자른다. 순서를 바꾸면 동작이 달라진다.

```swift
// ✅ 올바름 — fill로 확대한 뒤 자른다
Image(imageResource)
    .resizable()
    .scaledToFill()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipped()

// ⚠️ 잘못됨 — 자른 뒤에 프레임을 잡으면 의미가 없다
Image(imageResource)
    .resizable()
    .scaledToFill()
    .clipped()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
```

modifier 순서가 결과를 바꾼다는 원칙은 [ViewModifier 문서](./view-modifier-protocol.md)에서도 다뤘다.

**현재 코드는 `clipped()` 앞에 명시적인 `frame`이 없다.** 그래서 `ZStack`이 제안하는 크기가 레이아웃 경계가 된다. 동작은 하지만, 경계를 명시하면 의도가 분명해지고 예측 가능성이 올라간다.

```swift
Image(imageResource)
    .resizable()
    .scaledToFill()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipped()
```

`maxWidth`/`maxHeight`여야 한다는 점에 주의한다. `frame(width:height:)`는 **고정 크기**를 지정하는 modifier라 `.infinity`를 넣으면 안 된다.

> A view with **fixed dimensions** of width and height.

### `clipShape`와의 차이

`clipped()`는 사각형 경계로 자른다. 다른 모양으로 자르려면 `clipShape`를 쓴다.

```swift
.clipShape(.rect(cornerRadius: 20))
.clipShape(Circle())
```

예제의 `Text`가 이미 `.clipShape(.rect(cornerRadius: 30))`을 쓰고 있다. 둘 다 "그려지는 영역을 경계에 맞춘다"는 같은 계열이다.

### 남은 개선 여지

`clipped()`로 위치 흔들림은 해결됐지만, 두 가지가 더 있다.

**① `.ignoresSafeArea()`의 위치**

지금은 content 클로저 **안**에 있다.

```swift
} content: { imageResource in
    Image(imageResource)
        // ...
        .ignoresSafeArea()      // 매 phase마다 적용
}
```

safe area 계산이 phase마다 관여한다. `ZStack` 바깥에 한 번 붙이는 편이 단순하다.

**② `PhaseAnimator`는 이미지 크로스페이드에 맞지 않는다**

이것이 "끊기는" 느낌의 나머지 절반이다. `PhaseAnimator`는 phase에 따라 **modifier 값을 보간**한다. 그런데 이 코드는 `Image(imageResource)`에서 **이미지 자체를 교체**한다. 이미지 교체는 보간 대상이 아니라 즉각적으로 일어난다.

부드러운 크로스페이드를 원한다면 인덱스와 transition을 쓰는 편이 맞다.

```swift
@State private var index = 0

ZStack {
    Image(photoCollection[index])
        .resizable()
        .scaledToFill()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .id(index)
        .transition(.opacity)
}
.ignoresSafeArea()
.onTapGesture {
    withAnimation(.easeInOut(duration: 1)) {
        index = (index + 1) % photoCollection.count
    }
}
```

`.id(index)`가 이미지마다 별개의 뷰임을 알리고, `.transition(.opacity)`가 두 이미지를 겹쳐 페이드시킨다. 곡선도 스프링(`.snappy`)보다 `.easeInOut`이 자연스럽다. 세 API의 선택 기준은 [애니메이션 API 비교](./animation-api-comparison.md)에 정리했다.

### 정리

```text
원인
  ① 사진 비율이 제각각 (1:1 ~ 1:1.72)
  ② scaledToFill이 비율대로 확대 → 넘치는 양이 사진마다 다름
  ③ 기본적으로 넘친 부분은 잘리지 않고 그려짐
  ④ 그려지는 크기가 매번 달라져 레이아웃이 흔들림
  ⑤ PhaseAnimator가 그 흔들림까지 애니메이션

해결
  clipped()가 "그려지는 크기"를 "레이아웃 크기"에 고정
  → 사진 비율과 무관하게 영역이 일정
  → 애니메이션할 레이아웃 변화가 사라짐

원칙
  scaledToFill()을 쓰면 clipped()도 함께 쓴다.
```

## 학습 체크리스트

- [ ] `clipped()`를 지우고 pic3(가장 길쭉한 사진)에서 넘침이 가장 큰지 확인한다.
- [ ] `clipped()` 없이 `.border(.red)`를 붙여 레이아웃 경계와 실제 그림의 차이를 눈으로 본다.
- [ ] `scaledToFill()`을 `scaledToFit()`으로 바꿔 넘침이 사라지는 대신 여백이 생기는 것을 확인한다.
- [ ] `clipped()`를 `frame` 앞으로 옮겨 순서가 결과를 바꾸는 것을 확인한다.
- [ ] `.frame(maxWidth: .infinity, maxHeight: .infinity)`를 명시적으로 추가해 본다.
- [ ] `frame(width: .infinity)`와 `frame(maxWidth: .infinity)`의 차이를 문서에서 확인한다.
- [ ] 사진 6장의 실제 픽셀 비율을 확인하고 어느 것이 가장 많이 넘칠지 예측한다.
- [ ] `.snappy`를 `.easeInOut`으로 바꿔 출렁임이 줄어드는지 비교한다.
- [ ] `.ignoresSafeArea()`를 `ZStack` 바깥으로 옮기고 동작이 같은지 확인한다.
- [ ] `clipped()` 대신 `clipShape(.rect(cornerRadius: 20))`을 써 본다.
- [ ] `PhaseAnimator` 대신 인덱스 + `.transition(.opacity)` 방식으로 바꿔 크로스페이드를 만든다.
- [ ] 두 방식의 전환 부드러움을 나란히 비교한다.

## 공식 참고 자료

- [Apple: view.clipped(antialiased:)](https://developer.apple.com/documentation/swiftui/view/clipped(antialiased:))
- [Apple: view.clipShape(_:style:)](https://developer.apple.com/documentation/swiftui/view/clipshape(_:style:))
- [Apple: view.scaledToFill()](https://developer.apple.com/documentation/swiftui/view/scaledtofill())
- [Apple: view.scaledToFit()](https://developer.apple.com/documentation/swiftui/view/scaledtofit())
- [Apple: view.aspectRatio(_:contentMode:)](https://developer.apple.com/documentation/swiftui/view/aspectratio(_:contentmode:))
- [Apple: ContentMode](https://developer.apple.com/documentation/swiftui/contentmode)
- [Apple: view.frame(width:height:alignment:)](https://developer.apple.com/documentation/swiftui/view/frame(width:height:alignment:))
- [Apple: view.frame(minWidth:idealWidth:maxWidth:minHeight:idealHeight:maxHeight:alignment:)](https://developer.apple.com/documentation/swiftui/view/frame(minwidth:idealwidth:maxwidth:minheight:idealheight:maxheight:alignment:))
- [Apple: Image.resizable(capInsets:resizingMode:)](https://developer.apple.com/documentation/swiftui/image/resizable(capinsets:resizingmode:))
- [Apple: view.transition(_:)](https://developer.apple.com/documentation/swiftui/view/transition(_:))
- [Apple: Layout adjustments](https://developer.apple.com/documentation/swiftui/layout-adjustments)
