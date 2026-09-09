# `UIViewRepresentable`과 `UI` 접두사 — UIKit 컴포넌트를 SwiftUI로 가져오기

`NS` 접두사는 [별도 문서](./ns-prefix-foundation-classes.md)에, `CG`는 [여기](./coregraphics-types-and-cgfloat.md)에 정리했다. 이 문서는 **`UI` 접두사**와 **UIKit ↔ SwiftUI 연결**을 다룬다.

UIKit과 SwiftUI의 전체 아키텍처, 명령형·선언형 UI의 차이, `UIViewControllerRepresentable`과 `UIHostingController`까지 포함한 큰 그림은 [SwiftUI와 UIKit 아키텍처 학습 노트](./swiftui-and-uikit-architecture.md)에서 다룬다.

## 질문이 나온 코드

`chapter-61/chapter-61/ContentView.swift`

```swift
import SwiftUI
import WebKit
```

```swift
struct WebView: UIViewRepresentable {
    var url: URL

    func makeUIView(context: Context) -> WKWebView {
        .init()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.load(URLRequest(url: url))
    }
}
```

## 1부 — `WebKit` 모듈

### 무엇을 하는 프레임워크인가

> Use the WebKit framework to integrate richly styled web content into your app's native content. WebKit offers a full browsing experience for your content, offering a platform-native view and supporting classes to:
> - Display rich web content using HTML, CSS, and JavaScript
> - Handle the incremental loading of page content
> - Display multiple MIME types and compound frame elements
> - Navigate between pages of content
> - Manage a forward-back list of recently visited pages

**Safari의 렌더링 엔진을 앱에 넣는 것**이다. Safari 자체가 WebKit 위에서 동작하므로, `WKWebView`로 띄운 페이지는 Safari에서 보는 것과 같은 방식으로 렌더링된다.

### 주요 타입

| 타입 | 용도 |
| --- | --- |
| `WKWebView` | 웹 콘텐츠를 표시하는 뷰 — 핵심 |
| `WKWebViewConfiguration` | 생성 시 설정 (데이터 저장소, 미디어 정책 등) |
| `WKNavigationDelegate` | 페이지 이동을 가로채고 허용/거부 |
| `WKUIDelegate` | JavaScript `alert`, 새 창 요청 처리 |
| `WKUserContentController` | JavaScript 주입, 네이티브↔웹 메시지 |
| `WKScriptMessageHandler` | 웹에서 보낸 메시지 수신 |
| `WKWebsiteDataStore` | 쿠키·캐시 관리 |

`WK` 접두사는 **WebKit**의 약자다. 앞서 본 `NS`(Foundation), `CG`(Core Graphics), `UI`(UIKit)와 같은 관례다.

### 언제 쓰나

- 외부 링크를 **앱 안에서** 열 때 — 이 예제
- 약관·개인정보 처리방침처럼 웹으로 관리하는 문서
- OAuth 로그인 플로우
- 하이브리드 앱의 웹 화면

**대안도 알아 둘 만하다.**

| 방법 | 특징 |
| --- | --- |
| `WKWebView` (이 예제) | 완전한 제어. 커스터마이징 가능 |
| `SFSafariViewController` | Safari와 쿠키·비밀번호 공유. 툴바 제공. 커스터마이징 제한 |
| [`openURL`](./environment-property-wrapper.md) | Safari 앱으로 나간다 |

**단순히 링크를 보여 주는 것이 목적이라면 `SFSafariViewController`가 낫다.** 읽기 목록, 공유 시트, Reader 모드가 기본 제공되고 로그인 상태도 Safari와 공유된다. `WKWebView`는 JavaScript 연동이나 UI 커스터마이징이 필요할 때 쓴다.

**SwiftUI 전용 API도 생겼다.** WebKit 문서에 "WebKit for SwiftUI" 항목이 있고, 최근 SDK에는 `WebView`와 `WebPage` 타입이 추가됐다. 배포 타겟이 충분히 높다면 `UIViewRepresentable` 없이 쓸 수 있다. 다만 이 예제처럼 직접 감싸는 방식이 여전히 널리 쓰이고, 원리를 이해하는 데도 도움이 된다.

## 2부 — `UIViewRepresentable`

### 무엇을 하는 프로토콜인가

> Use a `UIViewRepresentable` instance to create and manage a `UIView` object in your SwiftUI interface. Adopt this protocol in one of your app's custom instances, and use its methods to create, update, and tear down your view.

**UIKit의 `UIView`를 SwiftUI 뷰로 감싸는 어댑터**다. SwiftUI에 없는 컴포넌트를 UIKit에서 빌려 올 때 쓴다.

선언을 보면 성질이 드러난다.

```swift
@MainActor @preconcurrency protocol UIViewRepresentable : View where Self.Body == Never
```

- **`View`를 상속한다** — 그래서 `WebView`를 다른 SwiftUI 뷰처럼 쓸 수 있다
- **`Body == Never`** — `body`를 구현하지 않는다. 대신 `makeUIView`가 그 역할을 한다
- **`@MainActor`** — UI 작업이므로 메인 액터에 격리된다

`Body == Never`가 흥미로운 지점이다. [`some View`와 opaque type](./some-keyword-opaque-types.md)에서 다룬 `View` 프로토콜의 `associatedtype Body`가 여기서는 `Never`로 고정된다. "반환할 수 없는 타입"이므로 `body`를 만들 수 없고, 실제로 만들 필요도 없다.

### 반드시 구현해야 하는 것 — 두 개

질문의 "반드시 오버라이딩 해야 하는 함수"에 대한 답이다. **오버라이드가 아니라 프로토콜 요구사항 구현**이고([hash(into:) 문서](./hash-into-and-java-comparison.md)에서 다룬 구분), 필수는 둘이다.

**① `makeUIView(context:)` — 뷰를 만든다**

```swift
func makeUIView(context: Context) -> WKWebView {
    .init()
}
```

**한 번만 호출된다.** SwiftUI가 이 뷰를 처음 만들 때 실행되고, 이후 뷰가 갱신되어도 다시 불리지 않는다. 그래서 여기서 초기 설정(델리게이트 지정, 설정 객체 전달)을 한다.

`.init()`은 `WKWebView()`의 축약이다. 반환 타입이 `WKWebView`로 적혀 있으므로 타입 추론이 되고, [implicit member expression](./static-type-properties-and-implicit-init.md)으로 타입 이름을 생략했다.

**② `updateUIView(_:context:)` — 상태를 반영한다**

```swift
func updateUIView(_ webView: WKWebView, context: Context) {
    webView.load(URLRequest(url: url))
}
```

**SwiftUI 상태가 바뀔 때마다 호출된다.** `url` 프로퍼티가 달라지면 이 함수가 다시 불려 새 페이지를 로드한다.

**반환 타입 추론 덕분에 `UIViewType`은 자동 결정된다.** 프로토콜에 `associatedtype UIViewType`이 있지만, `makeUIView`의 반환 타입에서 추론되므로 명시할 필요가 없다. [typealias와 associatedtype](./typealias-and-associated-type.md)에서 다룬 추론이다.

### 선택 구현 — 필요할 때만

| 멤버 | 용도 |
| --- | --- |
| `makeCoordinator()` | 델리게이트·타깃액션을 받을 객체 생성 |
| `dismantleUIView(_:coordinator:)` | 뷰가 사라질 때 정리 |
| `sizeThatFits(_:uiView:context:)` | 크기 계산을 직접 제어 |

**`Coordinator`가 가장 중요하다.** UIKit은 델리게이트 패턴을 쓰는데, `struct`인 representable은 델리게이트가 될 수 없다(클래스여야 하고 참조가 유지되어야 한다). 그래서 별도 객체가 필요하다.

> The system doesn't automatically communicate changes occurring within your view to other parts of your SwiftUI interface. When you want your view to coordinate with other SwiftUI views, you must provide a `Coordinator` instance to facilitate those interactions.

이 예제에는 없지만, 페이지 로딩 상태를 알아야 한다면 필요해진다.

```swift
struct WebView: UIViewRepresentable {
    var url: URL
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator   // 델리게이트 연결
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != url {              // 중복 로드 방지
            webView.load(URLRequest(url: url))
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebView
        init(parent: WebView) { self.parent = parent }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }
    }
}
```

`Coordinator`가 `NSObject`를 상속하는 이유는 UIKit 델리게이트 프로토콜이 Objective-C 기반이기 때문이다. [NS 접두사 문서](./ns-prefix-foundation-classes.md)에서 다룬 Objective-C 런타임 의존성이다.

### 이 예제에서 주의할 점

**`updateUIView`가 매번 `load`를 호출한다.**

```swift
func updateUIView(_ webView: WKWebView, context: Context) {
    webView.load(URLRequest(url: url))
}
```

SwiftUI가 이 뷰를 갱신할 때마다 페이지를 **다시 로드한다.** 사용자가 웹에서 링크를 눌러 다른 페이지로 이동했더라도, 부모 뷰가 재평가되면 원래 `url`로 되돌아간다. 스크롤 위치도 초기화된다.

```swift
// 개선 — 실제로 바뀔 때만 로드
func updateUIView(_ webView: WKWebView, context: Context) {
    if webView.url != url {
        webView.load(URLRequest(url: url))
    }
}
```

**레이아웃 프로퍼티를 직접 건드리면 안 된다.**

> **Warning:** SwiftUI fully controls the layout of the UIKit view's `center`, `bounds`, `frame`, and `transform` properties. Don't directly set these layout-related properties on the view managed by a `UIViewRepresentable` instance from your own code because that conflicts with SwiftUI and results in undefined behavior.

크기와 위치는 SwiftUI의 `frame` modifier로 조절한다.

## 3부 — `UI` 접두사의 히스토리

### `UI`는 UIKit이다

`NS`가 NeXTSTEP에서 왔다면, `UI`는 **User Interface**의 약자로 **UIKit** 프레임워크를 뜻한다.

**시간순으로 보면 이렇다.**

```text
1988~  NeXTSTEP
       AppKit (NS 접두사) — 데스크톱 UI

1997   Apple이 NeXT 인수
       NeXTSTEP → macOS의 기반
       AppKit이 Cocoa로 계승, NS 접두사 유지

2007   iPhone 등장
       터치 기반 UI가 필요 → AppKit을 쓸 수 없다
       UIKit 신설 (UI 접두사)

2008   iPhone SDK 공개, UIKit이 서드파티에 개방

2019   SwiftUI 등장
       접두사 없는 선언적 프레임워크
       UIKit·AppKit을 대체하지 않고 공존
```

**AppKit이 아니라 새 프레임워크를 만든 이유**는 입력 방식과 화면 크기가 근본적으로 달랐기 때문이다. 마우스 커서와 창(window) 개념에 기반한 AppKit을 터치 화면에 맞출 수 없었다.

### 플랫폼별 접두사 대응

같은 개념이 플랫폼마다 다른 이름을 갖는다.

| 개념 | iOS (UIKit) | macOS (AppKit) | SwiftUI |
| --- | --- | --- | --- |
| 뷰 | `UIView` | `NSView` | `View` |
| 색 | `UIColor` | `NSColor` | `Color` |
| 이미지 | `UIImage` | `NSImage` | `Image` |
| 폰트 | `UIFont` | `NSFont` | `Font` |
| 뷰 컨트롤러 | `UIViewController` | `NSViewController` | (없음) |
| 앱 | `UIApplication` | `NSApplication` | `App` |

**SwiftUI가 접두사를 버린 이유**는 두 가지다. Swift에 모듈 네임스페이스가 있어 접두사가 불필요하고, **플랫폼 공통 프레임워크**이므로 특정 플랫폼 이름을 붙일 수 없었다.

그래서 representable도 플랫폼별로 나뉜다.

| 프로토콜 | 감싸는 대상 | 플랫폼 |
| --- | --- | --- |
| `UIViewRepresentable` | `UIView` | iOS, tvOS |
| `UIViewControllerRepresentable` | `UIViewController` | iOS, tvOS |
| `NSViewRepresentable` | `NSView` | macOS |
| `NSViewControllerRepresentable` | `NSViewController` | macOS |
| `WKInterfaceObjectRepresentable` | watchOS 객체 | watchOS |

iOS와 macOS를 함께 지원하려면 조건부 컴파일이 필요하다.

```swift
#if os(iOS)
struct WebView: UIViewRepresentable { ... }
#elseif os(macOS)
struct WebView: NSViewRepresentable { ... }
#endif
```

### 언제 UIKit을 빌려 오나

SwiftUI가 성숙해지면서 필요가 줄었지만 여전히 있다.

- **SwiftUI에 없는 컴포넌트** — `WKWebView`(이 예제), `MKMapView`의 고급 기능, `PDFView`
- **세밀한 제어가 필요할 때** — `UITextView`의 커스텀 입력 처리
- **기존 UIKit 코드 재사용** — 점진적 마이그레이션
- **성능이 중요한 커스텀 뷰** — 직접 그리기

**반대 방향도 있다.** `UIHostingController`로 SwiftUI 뷰를 UIKit 앱에 넣을 수 있다. UIKit 앱에 SwiftUI를 점진적으로 도입할 때 쓴다.

### 정리

```text
WebKit
  Safari 엔진을 앱에 넣는 프레임워크. WK 접두사
  단순 링크 표시는 SFSafariViewController가 더 적합
  최신 SDK에는 SwiftUI 전용 WebView도 있다

UIViewRepresentable
  UIView를 SwiftUI 뷰로 감싸는 어댑터
  필수 구현 2개
    makeUIView(context:)     — 한 번만, 뷰 생성
    updateUIView(_:context:) — 상태가 바뀔 때마다
  선택: makeCoordinator (델리게이트), dismantleUIView, sizeThatFits
  금지: frame/bounds/center/transform 직접 설정

UI 접두사
  UIKit = User Interface Kit, 2007년 iPhone과 함께 신설
  AppKit(NS, 1988 NeXTSTEP)을 터치 환경에 맞게 다시 만든 것
  SwiftUI는 플랫폼 공통이므로 접두사가 없다
```

## 학습 체크리스트

- [ ] `import WebKit`을 지우고 `WKWebView`가 인식되지 않는 것을 확인한다.
- [ ] `makeUIView`에 `print`를 넣어 한 번만 호출되는지 확인한다.
- [ ] `updateUIView`에 `print`를 넣어 몇 번 호출되는지 관찰한다.
- [ ] 웹에서 링크를 눌러 다른 페이지로 간 뒤 뷰가 갱신되면 원래 URL로 돌아가는지 확인한다.
- [ ] `if webView.url != url` 조건을 추가해 중복 로드를 막아 본다.
- [ ] `.init()`을 `WKWebView()`로 바꿔 같은 것임을 확인한다.
- [ ] `Coordinator`를 만들어 `WKNavigationDelegate`로 로딩 완료를 감지한다.
- [ ] `@Binding var isLoading`으로 로딩 상태를 부모 뷰에 전달해 본다.
- [ ] `makeUIView` 안에서 `webView.frame`을 설정해 보고 문서의 경고를 확인한다.
- [ ] `body`를 구현하려 시도해 `Body == Never` 제약을 확인한다.
- [ ] 같은 URL을 `SFSafariViewController`로 띄워 보고 차이를 비교한다.
- [ ] `openURL`로 Safari 앱에서 열어 보고 세 방식을 비교한다.
- [ ] `UIViewControllerRepresentable`로 `UIImagePickerController`를 감싸 본다.
- [ ] `UIColor`와 `Color`를 서로 변환해 본다.

## 공식 참고 자료

**WebKit**

- [Apple: WebKit](https://developer.apple.com/documentation/webkit)
- [Apple: WKWebView](https://developer.apple.com/documentation/webkit/wkwebview)
- [Apple: WKNavigationDelegate](https://developer.apple.com/documentation/webkit/wknavigationdelegate)
- [Apple: WKWebViewConfiguration](https://developer.apple.com/documentation/webkit/wkwebviewconfiguration)
- [Apple: SFSafariViewController](https://developer.apple.com/documentation/safariservices/sfsafariviewcontroller)

**UIKit 연동**

- [Apple: UIViewRepresentable](https://developer.apple.com/documentation/swiftui/uiviewrepresentable)
- [Apple: UIViewRepresentable.makeUIView(context:)](https://developer.apple.com/documentation/swiftui/uiviewrepresentable/makeuiview(context:))
- [Apple: UIViewRepresentable.updateUIView(_:context:)](https://developer.apple.com/documentation/swiftui/uiviewrepresentable/updateuiview(_:context:))
- [Apple: UIViewRepresentable.makeCoordinator()](https://developer.apple.com/documentation/swiftui/uiviewrepresentable/makecoordinator())
- [Apple: UIViewControllerRepresentable](https://developer.apple.com/documentation/swiftui/uiviewcontrollerrepresentable)
- [Apple: NSViewRepresentable](https://developer.apple.com/documentation/swiftui/nsviewrepresentable)
- [Apple: UIHostingController](https://developer.apple.com/documentation/swiftui/uihostingcontroller)
- [Apple: UIKit](https://developer.apple.com/documentation/uikit)
- [Apple: AppKit](https://developer.apple.com/documentation/appkit)
