# `mask` — 알파 채널로 뷰를 오려내기

## 질문이 나온 코드

`chapter-165/chapter-165/ContentView.swift`

```swift
private func starView(for index: Int) -> some View {
    let fillAmount = min(max(animatedRating - Double(index), 0), 1)

    ZStack {
        Image(systemName: "star.fill")          // 아래: 회색 별 (빈 상태)
            .resizable()
            .scaledToFit()
            .foregroundStyle(.gray.gradient.opacity(0.5))
        Image(systemName: "star.fill")          // 위: 노란 별 (채워진 상태)
            .resizable()
            .scaledToFit()
            .foregroundStyle(
                LinearGradient(
                    colors: [.yellow, .orange],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .mask {
                GeometryReader { geometry in
                    Rectangle()
                        .frame(width: geometry.size.width * fillAmount)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
    }
    .frame(width: 30, height: 30)
}
```

`mask` 기능이 무엇인지가 질문이다.

## 공부할 내용

### 결론 먼저

`mask`는 **다른 뷰의 알파(투명도) 값을 스텐실처럼 씌워, 원본 뷰의 어느 부분을 보이게 할지 정하는 modifier**다.

공식 문서의 한 줄 정의다.

> Masks this view using the alpha channel of the given view.

핵심은 **"알파 채널"**이다. 마스크로 쓰인 뷰의 **색은 전혀 쓰이지 않고, 투명도만** 쓰인다.

```text
마스크의 알파   원본의 결과
   1.0 (불투명)  →  완전히 보인다
   0.5 (반투명)  →  반쯤 비친다
   0.0 (투명)    →  안 보인다
   그려지지 않은 영역 → 알파 0 → 안 보인다
```

별 채우기가 되는 원리가 이것이다. `Rectangle()`은 그려진 자리만 알파 1이고, 나머지는 아무것도 없어 알파 0이다. 그래서 **사각형이 덮은 만큼만 노란 별이 보인다.**

### 그림으로 보기

```text
원본 (노란 그라데이션 별)        마스크 (너비 60%인 흰 사각형)
  ★★★★★★★★★★                  ██████░░░░
   (전부 노랑)                    (알파1)(알파0)
            ↓  mask
        결과
  ★★★★★★☆☆☆☆
   왼쪽 60%만 노랑, 나머지는 잘려 아래 회색 별이 드러남
```

`ZStack` 아래에 회색 별이 깔려 있으므로, 잘려 나간 자리에는 **회색 별이 그대로 보인다.** 두 별이 정확히 겹쳐 있어 "부분적으로 채워진 하나의 별"처럼 읽힌다.

### 색은 정말로 무시되는가

그렇다. 마스크에 무슨 색을 써도 결과가 같다.

```swift
.mask { Rectangle().foregroundStyle(.red) }     // 결과 동일
.mask { Rectangle().foregroundStyle(.blue) }    // 결과 동일
.mask { Rectangle() }                           // 결과 동일
```

반면 **투명도를 바꾸면 결과가 달라진다.** 공식 문서의 예제가 그 점을 보여 준다.

```swift
Image(systemName: "envelope.badge.fill")
    .foregroundColor(Color.blue)
    .font(.system(size: 128, weight: .regular))
    .mask {
        Rectangle().opacity(0.1)
    }
```

사각형 전체가 알파 0.1이므로, 봉투 이미지 전체가 **10%만 비쳐 보인다.**

### 그라데이션 마스크 — 부드럽게 사라지기

알파가 연속적으로 변하는 마스크를 쓰면 페이드 효과가 된다. `mask`를 가장 많이 쓰는 용도 중 하나다.

```swift
Text("긴 본문이 아래로 갈수록 서서히 사라진다")
    .mask {
        LinearGradient(
            colors: [.black, .clear],   // 색은 무의미, 알파만 의미 있다
            startPoint: .top,
            endPoint: .bottom
        )
    }
```

`.black`과 `.clear`를 쓰는 이유는 **`.clear`의 알파가 0**이기 때문이다. `.black` 대신 `.white`나 `.red`를 써도 결과는 같다.

### `alignment` 파라미터

시그니처에 정렬 옵션이 있다.

```swift
nonisolated func mask<Mask>(
    alignment: Alignment = .center,
    @ContentBuilder _ mask: () -> Mask
) -> some View where Mask : View
```

마스크가 원본보다 작을 때 **어디에 붙일지**를 정한다. 기본값은 `.center`다.

```swift
Image(systemName: "star.fill")
    .mask(alignment: .leading) {        // 왼쪽에 붙여서 자른다
        Rectangle().frame(width: 20)
    }
```

질문의 코드는 `alignment` 대신 **안쪽에서 정렬을 처리**한다.

```swift
Rectangle()
    .frame(width: geometry.size.width * fillAmount)   // 실제 크기
    .frame(maxWidth: .infinity, alignment: .leading)  // 남은 공간에서 왼쪽 정렬
```

`frame`을 두 번 겹친 이 패턴은 **"작게 만든 뒤 부모 폭을 다 차지하되 왼쪽에 붙여라"**는 뜻이다. `mask(alignment: .leading)`을 써서 `frame` 하나를 줄일 수도 있다.

```swift
.mask(alignment: .leading) {
    GeometryReader { geometry in
        Rectangle().frame(width: geometry.size.width * fillAmount)
    }
}
```

두 `frame`을 겹치는 관용구는 [여러 `offset` modifier 문서](./chained-offset-modifiers.md)에서 다룬 "modifier는 순서대로 쌓인다"는 원리와 같은 맥락이다.

### 왜 `GeometryReader`가 필요한가

`fillAmount`는 0~1 사이의 **비율**인데, `frame(width:)`는 **포인트 단위**를 요구한다. 별의 실제 픽셀 폭을 알아야 곱할 수 있다.

```swift
GeometryReader { geometry in
    Rectangle()
        .frame(width: geometry.size.width * fillAmount)   // 30 × 0.7 = 21pt
}
```

`.frame(width: 30, height: 30)`이 바깥에 걸려 있으므로 `geometry.size.width`는 30이다. [`GeometryReader`를 언제 왜 쓰는가 문서](./geometry-reader-use-cases.md), [`GeometryReader`와 성능 문서](./geometry-reader-performance.md)를 참고한다.

iOS 17+라면 `containerRelativeFrame`으로도 비슷한 일을 할 수 있지만, **부모 컨테이너 기준**이라 이 경우처럼 자기 자신의 크기를 기준으로 삼기에는 `GeometryReader`가 맞다.

### `mask` vs `clipShape` vs `overlay` vs `blendMode`

비슷해 보이는 것들이 여럿 있다. 차이를 정리하면 이렇다.

| API | 기준 | 부분 투명 | 쓰는 상황 |
|---|---|---|---|
| `mask(_:)` | 임의의 **뷰**의 알파 | ✓ | 그라데이션 페이드, 부분 채우기 |
| `clipShape(_:)` | `Shape`의 **윤곽** | ✗ (이진) | 원형 아바타, 모서리 둥글리기 |
| `overlay(_:)` | 위에 덧그림 | — | 테두리, 배지 |
| `blendMode(.destinationOut)` | 픽셀 합성 | ✓ | 구멍 뚫기 (스포트라이트) |

**`clipShape`는 자를지 말지 둘 중 하나**다. 반투명 경계를 만들 수 없다.

```swift
Rectangle().clipShape(Circle())   // 원 안은 100%, 밖은 0%. 중간이 없다
Rectangle().mask { Circle().opacity(0.5) }   // 원 안이 50% — clipShape 로는 불가능
```

성능은 보통 `clipShape` 쪽이 가볍다. **단순히 모양대로 자르는 것이면 `clipShape`를 먼저 고려**하고, 알파 그라데이션이 필요할 때 `mask`를 쓴다.

### `mask`로 구멍 뚫기

역방향도 자주 쓴다. 마스크에서 **일부를 알파 0으로 만들면 그 부분만 뚫린다.**

```swift
Color.black.opacity(0.7)
    .mask {
        Rectangle()
            .overlay {
                Circle()
                    .frame(width: 100, height: 100)
                    .blendMode(.destinationOut)   // 원 부분의 알파를 0으로
            }
            .compositingGroup()                   // 합성 범위를 여기로 한정
    }
```

`compositingGroup()`이 중요하다. 없으면 `blendMode`가 **뷰 계층 전체**에 적용되어 엉뚱한 결과가 나온다. 온보딩 스포트라이트나 반투명 오버레이에 구멍을 낼 때 쓰는 관용구다.

### 자주 빠지는 함정

**① 마스크 뷰는 화면에 그려지지 않는다**

마스크로 넘긴 `Rectangle()`은 **어디에도 보이지 않는다.** 스텐실로만 쓰이고 버려진다. 디버깅할 때 마스크를 잠시 `overlay`로 바꿔 보면 모양을 눈으로 확인할 수 있다.

```swift
// 디버깅용: 마스크가 어떤 모양인지 보기
.overlay { Rectangle().frame(width: ...).opacity(0.3) }
```

**② 마스크의 크기가 레이아웃에 영향을 주지 않는다**

원본 뷰의 크기는 마스크와 무관하게 결정된다. 마스크가 아무리 작아도 **자리는 그대로 차지한다.** 질문의 코드에서 별 다섯 개의 간격이 채움 정도와 상관없이 일정한 이유다.

**③ 애니메이션은 마스크가 아니라 값이 한다**

```swift
withAnimation(.easeInOut(duration: 0.6)) {
    animatedRating = rating        // ← 이 값이 애니메이션된다
}
```

`mask` 자체에는 애니메이션 기능이 없다. `animatedRating`이 `Double`이라 보간되고, 그 결과 `fillAmount` → `frame(width:)`가 매 프레임 달라지면서 마스크가 자란다. 보간의 원리는 [`animatableData` 문서](./animatable-data-and-interpolation.md)에 정리되어 있다.

**④ `foregroundStyle`에 그라데이션을 쓰는 것과 다르다**

```swift
// 별 전체가 그라데이션으로 칠해진다 (부분 채우기 아님)
Image(systemName: "star.fill")
    .foregroundStyle(LinearGradient(...))

// 그라데이션으로 칠한 뒤 일부만 남긴다 (부분 채우기)
Image(systemName: "star.fill")
    .foregroundStyle(LinearGradient(...))
    .mask { Rectangle().frame(width: ...) }
```

질문의 코드는 **둘 다** 쓴다. 색칠은 `foregroundStyle`이, 잘라내기는 `mask`가 맡는다.

### 이 코드에 적용하면

```text
rating = 4.7,  index = 4 인 별
        ↓
fillAmount = min(max(4.7 - 4.0, 0), 1) = 0.7
        ↓
ZStack 아래:  회색 별 (항상 전체가 보임)
ZStack 위:    노란 그라데이션 별
                ↓ mask
              너비 30 × 0.7 = 21pt 인 Rectangle, 왼쪽 정렬
                ↓
              노란 별의 왼쪽 21pt 만 남는다
        ↓
결과: 70% 채워진 별
```

`min(max(..., 0), 1)`이 클램핑이다. `index = 0`이면 `4.7 - 0 = 4.7 → 1`(꽉 참), `index = 4`면 `0.7`(부분), `index`가 더 크면 음수 → `0`(빈 별)이 된다. **하나의 식으로 다섯 별의 상태가 전부 결정**된다.

## 체크리스트

- [ ] `mask`가 색이 아니라 알파만 쓴다는 것을 마스크 색을 바꿔 가며 확인한다.
- [ ] 마스크에 `.opacity(0.1)`을 주고 원본이 반투명해지는 것을 본다.
- [ ] `LinearGradient([.black, .clear])`로 페이드 아웃을 만들어 본다.
- [ ] 마스크의 `.black`을 `.red`로 바꿔도 결과가 같은지 확인한다.
- [ ] `mask(alignment: .leading)`으로 안쪽 `frame` 하나를 없애 본다.
- [ ] `GeometryReader`를 지우고 `frame(width: 20)` 고정값으로 바꿔 무엇이 깨지는지 본다.
- [ ] `mask`를 `clipShape`로 바꿔 보고 반투명 경계가 불가능한 것을 확인한다.
- [ ] 마스크 내용을 `overlay`로 옮겨 어떤 모양인지 눈으로 본다.
- [ ] 채움 정도를 바꿔도 별 간격이 그대로인 것을 확인한다.
- [ ] `blendMode(.destinationOut)` + `compositingGroup()`으로 구멍 뚫기를 만들어 본다.
- [ ] `compositingGroup()`을 빼고 무엇이 잘못되는지 관찰한다.
- [ ] `fillAmount` 식에 `rating = 4.7`, `index = 0...4`를 대입해 다섯 값을 손으로 계산한다.

## 공식 참고 자료

- [SwiftUI: mask(alignment:_:)](https://developer.apple.com/documentation/swiftui/view/mask(alignment:_:))
- [SwiftUI: clipShape(_:style:)](https://developer.apple.com/documentation/swiftui/view/clipshape(_:style:))
- [SwiftUI: compositingGroup()](https://developer.apple.com/documentation/swiftui/view/compositinggroup())
- [SwiftUI: blendMode(_:)](https://developer.apple.com/documentation/swiftui/view/blendmode(_:))
- [SwiftUI: BlendMode](https://developer.apple.com/documentation/swiftui/blendmode)
- [SwiftUI: LinearGradient](https://developer.apple.com/documentation/swiftui/lineargradient)
- [SwiftUI: GeometryReader](https://developer.apple.com/documentation/swiftui/geometryreader)
- [SwiftUI: foregroundStyle(_:)](https://developer.apple.com/documentation/swiftui/view/foregroundstyle(_:))
- [SwiftUI: Alignment](https://developer.apple.com/documentation/swiftui/alignment)
