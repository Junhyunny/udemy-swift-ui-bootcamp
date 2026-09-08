# `AsyncImage` — `Image`와 무엇이 다른가

## 질문이 나온 코드

`chapter-61/chapter-61/ContentView.swift`

```swift
AsyncImage(url: URL(string: imageURL)!) { image in
    image
        .resizable()
        .scaledToFit()
} placeholder: {
    Image(systemName: "photo")
        .resizable()
        .scaledToFit()
}
.clipped()
```

## 공부할 내용

### 결론 먼저

- `Image`는 **앱 번들이나 메모리에 이미 있는** 이미지를 그린다.
- `AsyncImage`는 **네트워크에서 내려받아** 그린다. 로딩 시간이 있으므로 placeholder가 필요하다.
- 다운로드는 `URLSession.shared`가 처리한다. 직접 async 코드를 쓸 필요가 없다.
- **`AsyncImage`에는 이미지 modifier를 직접 붙일 수 없다.** content 클로저 안의 `image`에 붙여야 한다.
- **이 코드에는 크래시 위험이 있다.** `URL(string: imageURL)!`의 강제 언래핑이다.

### 무엇을 하는가

> This view uses the shared `URLSession` instance to load an image from a URL that you specify, and then display it.

가장 단순한 형태는 이렇다.

```swift
AsyncImage(url: URL(string: "https://example.com/icon.png"))
    .frame(width: 200, height: 200)
```

> Until the image loads, the view displays a standard placeholder that fills the available space. After the load completes successfully, the view updates to display the image.

**로딩 중에는 기본 placeholder를 보여 주고, 완료되면 이미지로 바뀐다.** 이 상태 전환이 `AsyncImage`의 존재 이유다.

### `Image`와의 차이

| | `Image` | `AsyncImage` |
| --- | --- | --- |
| 이미지 출처 | 앱 번들, `UIImage`, SF Symbol | **네트워크 URL** |
| 로딩 시간 | 없음 (동기) | **있음 (비동기)** |
| placeholder | 불필요 | **필요** |
| 실패 처리 | 이름이 틀리면 빈 뷰 | 상태로 구분 가능 |
| modifier 적용 | 직접 붙인다 | **content 클로저 안에서** |
| 캐싱 | 시스템이 관리 | `URLSession` 캐시 |

`Image`는 이 예제에도 나온다.

```swift
placeholder: {
    Image(systemName: "photo")      // SF Symbol — 즉시 그려진다
}
```

[`ImageResource` 문서](./image-resource-and-asset-symbols.md)에서 다룬 `Image(.pic1)`도 번들 이미지라 즉시 표시된다. **원격 이미지만 `AsyncImage`가 필요하다.**

### modifier를 붙이는 위치 — 가장 흔한 실수

Apple이 명시적으로 경고한다.

> **Important:** You can't apply image-specific modifiers, like `resizable(capInsets:resizingMode:)`, directly to an `AsyncImage`. Instead, apply them to the `Image` instance that your content closure gets when defining the view's appearance.

```swift
// ❌ 안 된다 — AsyncImage에 직접
AsyncImage(url: url)
    .resizable()
    .scaledToFit()

// ✅ content 클로저 안의 image에
AsyncImage(url: url) { image in
    image
        .resizable()
        .scaledToFit()
} placeholder: {
    ProgressView()
}
```

**이유는 타입이다.** `resizable()`은 `Image`의 메서드이고 `AsyncImage`는 별개의 타입이다. 로딩이 끝나기 전에는 `Image` 인스턴스가 존재하지도 않는다.

이 예제는 올바르게 쓰고 있다.

```swift
AsyncImage(url: ...) { image in
    image
        .resizable()      // ← image에 붙였다
        .scaledToFit()
}
```

반면 `.clipped()`는 `AsyncImage` 바깥에 붙어 있는데, 이건 **`View`의 modifier이므로 문제없다.** `resizable()`처럼 `Image` 전용인 것만 안쪽에 붙이면 된다.

`scaledToFill()`을 쓸 때 `.clipped()`가 필요한 이유는 [별도 문서](./scaled-to-fill-and-clipped.md)에 정리했다. 이 예제는 `scaledToFit()`이라 넘침이 없지만, `clipped()`가 있어도 무해하다.

### 이니셜라이저 세 가지

**① 가장 단순 — 기본 placeholder**

```swift
AsyncImage(url: url)
```

**② content + placeholder — 이 예제**

```swift
AsyncImage(url: url) { image in
    image.resizable()
} placeholder: {
    ProgressView()
}
```

**③ `phase`로 상태를 직접 다룬다 — 가장 강력**

```swift
AsyncImage(url: url) { phase in
    switch phase {
    case .empty:
        ProgressView()
    case .success(let image):
        image.resizable().scaledToFit()
    case .failure(let error):
        Image(systemName: "exclamationmark.triangle")
            .foregroundStyle(.orange)
    @unknown default:
        EmptyView()
    }
}
```

`AsyncImagePhase`가 세 상태를 갖는다.

| 상태 | 의미 |
| --- | --- |
| `.empty` | 아직 로딩 중이거나 URL이 `nil` |
| `.success(Image)` | 로딩 성공 |
| `.failure(Error)` | 로딩 실패 |

**②는 실패와 로딩 중을 구분하지 못한다.** 둘 다 placeholder가 표시된다. 이 예제도 그래서 이미지 로딩이 실패하면 `photo` 심볼이 계속 남아 있는데, 사용자는 "로딩 중"인지 "실패"인지 알 수 없다.

**실패를 구분하려면 ③을 써야 한다.**

### 애니메이션과 스케일

추가 파라미터가 두 개 있다.

```swift
AsyncImage(url: url, scale: 2.0, transaction: Transaction(animation: .easeIn)) { phase in
    // ...
}
```

- **`scale`** — 이미지의 배율. 2x 이미지를 내려받았다면 `2.0`을 주어 논리 크기를 맞춘다. [asset catalog의 배율](./asset-catalog-universal-scale.md)과 같은 개념이다
- **`transaction`** — 상태 전환에 애니메이션을 준다. placeholder에서 이미지로 바뀔 때 페이드인 효과

### 캐싱 — 알아 둘 제약

`AsyncImage`는 `URLSession.shared`를 쓰므로 **HTTP 캐시 정책을 따른다.** 서버가 `Cache-Control` 헤더를 주면 그에 맞게 캐시된다.

**하지만 메모리 이미지 캐시는 없다.** 디코딩된 이미지를 메모리에 유지하지 않으므로, 리스트를 스크롤해 화면 밖으로 나갔다 돌아오면 **다시 디코딩**된다. 긴 목록에서 스크롤이 버벅이는 원인이 될 수 있다.

이 예제처럼 `List`에서 각 행마다 `AsyncImage`를 쓰면 그 영향을 받는다. 개선이 필요하면 선택지가 있다.

- `URLCache`를 설정해 디스크·메모리 캐시 크기를 늘린다
- 직접 이미지 캐시를 구현한다 (`NSCache` + `Task`)
- 서드파티 라이브러리를 쓴다

학습 예제에서는 `AsyncImage`로 충분하다. 성능이 문제가 되는 시점에 고민하면 된다.

### 이 코드의 문제 — 강제 언래핑

**여기가 실제로 위험한 지점이다.**

```swift
CardView(
    // ...
    imageURL: article.urlToImage ?? ""      // ← nil이면 빈 문자열
)
```

```swift
AsyncImage(url: URL(string: imageURL)!)    // ← 빈 문자열이면 nil → 크래시
```

**연쇄를 따라가 보면 이렇다.**

```text
① article.urlToImage가 nil (NewsAPI에서 흔하다)
        ↓
② ?? ""로 빈 문자열이 된다
        ↓
③ URL(string: "")는 nil을 반환한다
        ↓
④ 강제 언래핑 ! → 크래시
```

**`urlToImage`가 `String?`으로 선언된 것 자체가 "없을 수 있다"는 뜻이다.** NewsAPI는 이미지가 없는 기사를 자주 내려보낸다. 즉 이 크래시는 이론적 가능성이 아니라 **실제로 재현될 것이다.**

**`AsyncImage`는 `url`이 옵셔널을 받는다.**

```swift
init(url: URL?, scale: CGFloat = 1, ...)
```

`nil`을 넘기면 `.empty` 상태가 되어 placeholder가 표시된다. **강제 언래핑할 필요가 전혀 없다.**

**개선안**

```swift
struct CardView: View {
    var title: String
    var desc: String
    var author: String
    var imageURL: String?          // 옵셔널로 받는다

    var body: some View {
        VStack {
            AsyncImage(url: imageURL.flatMap(URL.init(string:))) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Image(systemName: "photo").resizable().scaledToFit()
            }
            // ...
        }
    }
}
```

호출부에서 `?? ""`도 사라진다.

```swift
CardView(
    title: article.title,
    desc: article.description ?? "",
    author: article.author ?? "",
    imageURL: article.urlToImage          // 그대로 전달
)
```

`URL(string:)`이 실패해도 `nil`이 되어 placeholder가 나온다. 크래시가 없다.

**같은 문제가 `WebView`에도 있다.**

```swift
WebView(url: URL(string: url)!)
```

`article.url`은 보통 유효하지만, 강제 언래핑은 여전히 위험하다. [guard 문서](./guard-keyword.md)에서 다룬 방식으로 처리하는 편이 안전하다.

**placeholder에 대한 참고사항**도 있다.

> If you use an `AsyncImage` as a placeholder view and it doesn't load, SwiftUI doesn't show anything as a placeholder and doesn't report an error.

placeholder에 또 `AsyncImage`를 넣으면 안 된다는 뜻이다. 이 예제는 SF Symbol을 쓰므로 문제없다.

### 정리

```text
Image        번들·메모리 이미지, 즉시 그려진다
AsyncImage   네트워크 이미지, 로딩 상태가 있다
             URLSession.shared가 다운로드를 처리

modifier 위치
  resizable() 같은 Image 전용 → content 클로저 안의 image에
  clipped() 같은 View 전용    → AsyncImage 바깥에 가능

이니셜라이저
  url만           기본 placeholder
  content + placeholder   로딩/실패를 구분 못 한다  ← 이 예제
  phase           .empty / .success / .failure 구분 가능

주의
  url이 옵셔널을 받으므로 강제 언래핑이 불필요하다
  메모리 이미지 캐시가 없어 긴 목록에서는 재디코딩된다
```

## 학습 체크리스트

- [ ] `urlToImage`가 `null`인 기사를 찾아 크래시가 재현되는지 확인한다.
- [ ] `imageURL`을 옵셔널로 바꾸고 강제 언래핑을 제거한다.
- [ ] `URL(string: "")`이 `nil`을 돌려주는 것을 직접 확인한다.
- [ ] `AsyncImage(url: nil)`을 넣어 placeholder가 표시되는지 확인한다.
- [ ] `.resizable()`을 `AsyncImage`에 직접 붙여 컴파일 에러를 확인한다.
- [ ] `.clipped()`는 바깥에 붙어도 되는 이유를 설명한다.
- [ ] `phase` 기반 이니셜라이저로 바꿔 `.failure`를 별도로 표시한다.
- [ ] 존재하지 않는 URL을 주고 `.failure`가 실제로 오는지 확인한다.
- [ ] `transaction: Transaction(animation: .easeIn)`으로 페이드인을 넣어 본다.
- [ ] `scale: 2.0`을 주고 이미지 크기가 어떻게 달라지는지 본다.
- [ ] 리스트를 길게 스크롤해 이미지가 다시 로딩되는지 관찰한다.
- [ ] placeholder를 `ProgressView()`로 바꿔 로딩 중임이 드러나게 한다.
- [ ] `Image(systemName:)`과 `AsyncImage`의 표시 시점 차이를 눈으로 비교한다.

## 공식 참고 자료

- [Apple: AsyncImage](https://developer.apple.com/documentation/swiftui/asyncimage)
- [Apple: AsyncImage.init(url:scale:content:placeholder:)](https://developer.apple.com/documentation/swiftui/asyncimage/init(url:scale:content:placeholder:))
- [Apple: AsyncImage.init(url:scale:transaction:content:)](https://developer.apple.com/documentation/swiftui/asyncimage/init(url:scale:transaction:content:))
- [Apple: AsyncImagePhase](https://developer.apple.com/documentation/swiftui/asyncimagephase)
- [Apple: Image](https://developer.apple.com/documentation/swiftui/image)
- [Apple: Image.resizable(capInsets:resizingMode:)](https://developer.apple.com/documentation/swiftui/image/resizable(capinsets:resizingmode:))
- [Apple: Transaction](https://developer.apple.com/documentation/swiftui/transaction)
- [Apple: URLCache](https://developer.apple.com/documentation/foundation/urlcache)
- [Apple: URLSession](https://developer.apple.com/documentation/foundation/urlsession)
- [Apple: URL.init(string:)](https://developer.apple.com/documentation/foundation/url/init(string:))
