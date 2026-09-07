# `overlay`는 무엇이고, 왜 화면이 까맣게 덮였나

## 질문이 나온 코드

`chapter-34/chapter-34/ContentView.swift`의 `CardView`에 붙은 `.overlay { RoundedRectangle(cornerRadius: 20).stroke(...) }`

## 공부할 내용

### `overlay`는 "앞에 덧대는" modifier다

> "Layers the views that you specify in front of this view."
>
> "Use this modifier to place one or more views in front of another view."

원래 뷰의 **레이아웃 크기는 그대로 두고**, 그 위에 다른 뷰를 겹쳐 그린다. 카드 테두리, 배지, 그라디언트 덮개처럼 "원본 크기에 맞춰 위에 얹을 것"에 쓴다. 반대 방향으로 뒤에 까는 것은 `background`다.

`alignment`로 위치를 정할 수 있고, 기본값은 `.center`다.

```swift
RoundedRectangle(cornerRadius: 8)
    .frame(width: 200, height: 100)
    .overlay(alignment: .topLeading) { Star(color: .red) }
    .overlay(alignment: .topTrailing) { Star(color: .yellow) }
```

클로저 안에 뷰를 여러 개 쓰면 암묵적 `ZStack`으로 묶인다.

> "If you specify more than one view in the `content` closure, the modifier collects all of the views in the closure into an implicit `ZStack`, taking them in order from back to front."
>
> "If you specify an alignment for the overlay, it applies to the implicit stack rather than to the individual views in the closure."

### 왜 화면이 전부 까맣게 됐나 — `Shape`의 기본 동작 때문이다

`overlay`가 잘못된 게 아니다. 원인은 **덧댄 뷰가 `Shape`였다는 것**에 있다.

> "Shapes without an explicit fill or stroke get a default fill based on the foreground color."

즉 `RoundedRectangle(cornerRadius: 20)`를 그냥 쓰면 **테두리가 아니라 속이 꽉 찬 도형**이 되고, 색은 foreground color를 따라간다. 라이트 모드의 기본 foreground는 검정에 가까우므로, 카드 크기에 딱 맞는 검은 사각형이 카드 위를 완전히 덮는다. 화면이 까매진 이유가 이것이다.

```swift
.overlay { RoundedRectangle(cornerRadius: 20) }                       // 까맣게 덮인다
.overlay { RoundedRectangle(cornerRadius: 20).stroke(.gray, lineWidth: 2) }  // 테두리만
```

`stroke(_:lineWidth:)`를 붙이면 채우기 대신 **윤곽선만** 그리므로 안쪽이 비어 내용이 보인다. 지금 코드는 이미 `.stroke(.gray.opacity(0.4), lineWidth: 2)`가 붙어 있어 의도대로 동작한다. `fill(_:)`로 색을 주면 여전히 꽉 찬 도형이지만 원하는 색으로 칠할 수 있다.

정리하면 **"overlay가 덮는다"가 아니라 "채워진 Shape가 덮는다"** 가 정확한 진단이다. 같은 일이 `background`에서도 일어나지만, 뒤에 깔리므로 눈에 덜 띈다.

### 함께 알아 둘 점

- `.clipShape(.rect(cornerRadius: 20))`로 잘라낸 모서리와 `overlay`의 `RoundedRectangle(cornerRadius: 20)`은 **반지름을 같게 맞춰야** 테두리가 어긋나지 않는다. 지금 코드는 둘 다 20이라 맞다.
- `overlay`는 원본의 레이아웃 크기를 바꾸지 않는다. 그래서 테두리를 그려도 카드 크기가 커지지 않는다.
- `stroke`는 선이 경계선 **중앙**에 그려져 절반이 밖으로 나간다. `clipShape` 뒤에 `overlay`를 두면 바깥 절반이 잘려 선이 얇아 보일 수 있다. 두께가 기대와 다르면 이 점을 의심한다.
- 지금 코드의 `.shadow(color: .red, radius: 4)`는 `stroke`된 선에 걸린 그림자다. 카드 전체 그림자를 원한다면 위치가 다르다.

## 학습 체크리스트

- [ ] `.stroke(...)`를 지우고 `RoundedRectangle(cornerRadius: 20)`만 남겨 까맣게 덮이는 것을 재현한다.
- [ ] 그 상태에서 `.foregroundStyle(.red)`를 붙여 색이 foreground를 따라가는 것을 확인한다.
- [ ] `.stroke` 대신 `.fill(.blue.opacity(0.3))`을 써서 반투명하게 덮어 본다.
- [ ] 다크 모드로 전환해 기본 채우기 색이 달라지는지 확인한다.
- [ ] `overlay`를 `background`로 바꿔 앞뒤 순서가 어떻게 달라지는지 본다.
- [ ] `overlay(alignment: .topTrailing)`으로 배지를 얹어 정렬 옵션을 실험한다.
- [ ] `overlay` 클로저에 뷰를 두 개 넣고 암묵적 `ZStack`으로 묶이는 것을 확인한다.
- [ ] `clipShape`의 반지름만 30으로 바꿔 테두리가 어긋나는 것을 관찰한다.
- [ ] `lineWidth`를 10으로 키우고 `clipShape` 앞뒤로 `overlay` 위치를 바꿔 선 두께 차이를 비교한다.

## 참고 자료

- [Apple: View.overlay(alignment:content:)](https://developer.apple.com/documentation/swiftui/view/overlay(alignment:content:))
- [Apple: Shape](https://developer.apple.com/documentation/swiftui/shape)
- [Apple: Shape.stroke(_:lineWidth:antialiased:)](https://developer.apple.com/documentation/swiftui/shape/stroke(_:linewidth:antialiased:))
- [Apple: Shape.fill(_:style:)](https://developer.apple.com/documentation/swiftui/shape/fill(_:style:))
- [Apple: RoundedRectangle](https://developer.apple.com/documentation/swiftui/roundedrectangle)
- [Apple: View.background(alignment:content:)](https://developer.apple.com/documentation/swiftui/view/background(alignment:content:))
- [Apple: View.clipShape(_:style:)](https://developer.apple.com/documentation/swiftui/view/clipshape(_:style:))
- [Apple: View.foregroundStyle(_:)](https://developer.apple.com/documentation/swiftui/view/foregroundstyle(_:))
- [Apple: ZStack](https://developer.apple.com/documentation/swiftui/zstack)
