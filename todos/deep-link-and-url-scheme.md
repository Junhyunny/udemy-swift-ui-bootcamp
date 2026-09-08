# 딥링크와 커스텀 URL 스킴 — 용도와 Info.plist 프로퍼티

브라우저에서 앱을 찾아가는 **동작 원리와 스킴 충돌**은 [별도 문서](./url-scheme-resolution-and-conflicts.md)에 있다. 이 문서는 **무엇에 쓰는가**와 **설정 항목의 의미**를 다룬다.

## 질문이 나온 코드

`chapter-51/chapter-51/Info.plist`

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.devtechie.app</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>devtechie</string>
        </array>
    </dict>
</array>
```

`chapter-51/chapter-51/ContentView.swift`

```swift
.onOpenURL { url in
    latestURL = url
    text += "\nOpened URL: \(url)"
    coordinator.handleDeepLinkURL(url)
}
```

## 1부 — 딥링크는 무엇에 쓰는가

### 그렇다, 특정 URL을 내 앱으로 연결하는 기능이다

질문의 이해가 정확하다. Apple의 정의가 그대로다.

> Custom URL schemes provide a way to reference resources inside your app. Users tapping a custom URL in an email, for example, launch your app in a specified context. Other apps can also trigger your app to launch with specific context data; for example, a photo library app might display a specified image.

핵심은 **"in a specified context"** — 앱을 그냥 여는 것이 아니라 **특정 화면·상태로** 연다는 점이다. 이것이 "deep"의 의미다. 앱의 첫 화면(surface)이 아니라 **깊은 곳(deep)으로 바로 진입**한다.

이 예제가 정확히 그 구조다.

```text
devtechie://test     →  앱 실행 + TestView로 이동
devtechie://support  →  앱 실행 + SupportView로 이동
```

```swift
func handleDeepLinkURL(_ url: URL) {
    guard url.scheme == "devtechie" else { return }
    switch url.host {
    case "test":    path.append(Route.test)
    case "support": path.append(Route.support)
    default:        break
    }
}
```

`url.host`로 목적지를 판별해 `NavigationPath`에 쌓는다. 딥링크의 전형적인 구현이다.

### URL의 어느 부분이 무엇인가

```text
devtechie://test?message=hello&id=42
└───┬───┘   └┬─┘ └──────┬──────────┘
 scheme     host       query
```

| 코드 | 값 |
| --- | --- |
| `url.scheme` | `"devtechie"` |
| `url.host` | `"test"` |
| `url.path` | `""` |
| `url.query` | `"message=hello&id=42"` |

예제의 `handleURL`이 `url.query`를 그대로 화면에 보여 주는 것도 이 구조를 확인하기 위한 것이다.

### 실제 사용 케이스

**1. 마케팅·프로모션 링크**

이메일이나 문자의 링크를 누르면 앱의 해당 상품 페이지로 바로 간다. 웹으로 갔다가 "앱에서 열기"를 다시 누르게 하지 않는다.

**2. 푸시 알림 탭 처리**

알림 페이로드에 URL을 실어 두고, 사용자가 알림을 누르면 관련 화면으로 이동시킨다.

**3. 앱 간 연동**

다른 앱이 내 앱을 특정 상태로 실행시킨다.

> Other apps can also trigger your app to launch with specific context data; for example, a photo library app might display a specified image.

```swift
// 다른 앱에서
let url = URL(string: "myphotoapp:Vacation?index=1")
UIApplication.shared.open(url!) { (result) in
    if result {
       // The URL was delivered successfully!
    }
}
```

[chapter-48의 `openURL`](./environment-property-wrapper.md)이 이 호출부에 해당한다. 즉 딥링크는 **보내는 쪽과 받는 쪽**이 있고, chapter-48은 보내는 쪽, chapter-51은 받는 쪽이다.

**4. OAuth·결제 콜백**

가장 실무적인 용도다. 외부 브라우저에서 로그인을 마친 뒤 앱으로 돌아와야 할 때 커스텀 스킴이 리디렉션 목적지가 된다.

```text
myapp://oauth/callback?code=abc123
```

카카오·네이버 로그인 SDK, 결제 모듈이 앱마다 고유 스킴을 요구하는 이유가 이것이다.

**5. 앱 내 화면 간 이동을 URL로 통일**

내부 네비게이션까지 URL로 표현하면 라우팅이 한 곳에 모인다. 예제의 `NavigationCoordinator`가 그 방향이다.

**6. 시스템 스킴 사용**

내 앱을 등록하는 것과 반대로, 시스템이 제공하는 스킴을 쓰는 경우도 있다.

> Apple supports common schemes associated with system apps, such as `mailto`, `tel`, `sms`, and `facetime`.

chapter-49에서 `mailto:`와 설정 앱 URL을 열어 본 것이 이 경우다.

**7. 테스트·QA 자동화**

특정 화면을 바로 띄워 검증한다. 터미널에서 이렇게 쓴다.

```
xcrun simctl openurl booted "devtechie://test?message=hello"
```

### 중요한 권고 — Universal Links가 우선이다

Apple이 명확히 말한다.

> While custom URL schemes are an acceptable form of deep linking, **universal links are strongly recommended**.

Universal Links는 일반 HTTP(S) 링크를 앱으로 연결하는 방식이다.

> When users tap or click a universal link, the system redirects the link directly to your app without routing through the person's default web browser or your website. In addition, because universal links are standard HTTP or HTTPS links, one URL works for both your website and your app. If the person hasn't installed your app, the system opens the URL in their default web browser, allowing your website to handle it.

차이를 정리하면 이렇다.

| | 커스텀 스킴 | Universal Links |
| --- | --- | --- |
| URL 형태 | `devtechie://test` | `https://devtechie.com/test` |
| 앱 미설치 시 | **아무 일도 안 일어남** | 웹페이지가 열림 |
| 소유권 검증 | **없음** | 서버의 `apple-app-site-association` 파일로 검증 |
| 스킴 도용 | **가능** | 불가능 |
| 설정 난이도 | 쉬움 (Info.plist만) | 서버 파일 + Associated Domains 필요 |
| 학습·프로토타입 | 적합 | 과함 |

소유권 검증이 결정적 차이다.

> When someone installs your app, the system checks a file stored on your web server to verify that your website allows your app to open URLs on its behalf. Only you can store this file on your server, securing the association of your website and your app.

커스텀 스킴은 아무나 `devtechie`를 등록할 수 있지만, Universal Links는 도메인 소유자만 연결할 수 있다. 자세한 충돌 이야기는 [스킴 해석과 충돌 문서](./url-scheme-resolution-and-conflicts.md)에 있다.

**다만 커스텀 스킴이 여전히 필요한 경우도 있다.** OAuth 콜백처럼 외부 SDK가 요구하는 경우, 앱이 반드시 설치되어 있다고 전제할 수 있는 경우가 그렇다.

### 보안 경고 — 반드시 검증할 것

Apple의 경고가 강하다.

> **Warning:** URL schemes offer a potential attack vector into your app, so make sure to validate all URL parameters and discard any malformed URLs. In addition, limit the available actions to those that don't risk the user's data. For example, don't allow other apps to directly delete content or access sensitive information about the user. When testing your URL-handling code, make sure your test cases include improperly formatted URLs.

**누구나 내 앱에 URL을 보낼 수 있다**는 것이 전제다. 그래서 이렇게 다뤄야 한다.

- 스킴·호스트를 반드시 확인한다 — 예제의 `guard url.scheme == "devtechie"`가 그 최소 조치다
- 파라미터를 검증한다. 특히 ID나 경로를 그대로 신뢰하지 않는다
- 삭제·결제·개인정보 노출 같은 위험한 동작을 딥링크로 노출하지 않는다
- 잘못된 형식의 URL을 테스트 케이스에 포함한다

파싱은 문자열을 직접 자르지 말고 `URLComponents`를 쓰는 것이 권장된다.

> To ensure the URL is parsed correctly, use `URLComponents` APIs to extract the components.

```swift
guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
      let host = components.host else { return }

let params = components.queryItems ?? []
let id = params.first(where: { $0.name == "id" })?.value
```

예제의 `url.query`를 그대로 쓰는 방식은 `"message=hello&id=42"`라는 문자열 전체를 받으므로, 실제 앱에서는 `queryItems`로 파싱하는 편이 낫다.

## 2부 — Info.plist의 URL Types 프로퍼티

Xcode의 Info 탭에서 URL Types를 추가하면 나오는 항목들이다. 각각이 `Info.plist`의 어떤 키에 대응하는지부터 정리한다.

| Xcode 표시 | Info.plist 키 | 타입 |
| --- | --- | --- |
| (섹션 전체) | `CFBundleURLTypes` | 딕셔너리 배열 |
| Identifier | `CFBundleURLName` | String |
| URL Schemes | `CFBundleURLSchemes` | String 배열 |
| Role | `CFBundleTypeRole` | String |
| Icon | `CFBundleURLIconFile` | String |
| Additional url type properties | (임의 키) | — |

`CFBundleURLTypes`가 **배열**이라는 점이 중요하다. 하나의 앱이 여러 URL 타입을 등록할 수 있다.

### ① URL Schemes (`CFBundleURLSchemes`)

**실제로 동작을 결정하는 유일한 항목이다.**

> In the URL Schemes box, specify the prefix you use for your URLs.

예제의 `devtechie`가 여기 들어간다. `devtechie://`로 시작하는 URL이 이 앱으로 온다.

**배열이라 여러 개를 넣을 수 있다.**

```xml
<key>CFBundleURLSchemes</key>
<array>
    <string>devtechie</string>
    <string>devtechie-dev</string>
</array>
```

개발용·운영용 스킴을 분리하거나, 구 버전 스킴을 호환용으로 남길 때 쓴다.

**작성 규칙**

- 소문자를 쓴다. 대소문자 처리가 시스템마다 다를 수 있다
- `://`나 슬래시를 넣지 않는다. 스킴 이름만 적는다
- `http`, `https`, `mailto`, `tel` 같은 예약 스킴은 쓸 수 없다
- 충돌을 줄이려면 앱 고유의 이름을 쓴다. `app`, `test` 같은 일반적 단어는 위험하다

### ② Identifier (`CFBundleURLName`)

**동작에 영향을 주지 않는 이름표**다. 이 점을 오해하기 쉽다.

> Specify an identifier for your app.
>
> The identifier you supply with your scheme distinguishes your app from others that declare support for the same scheme. To ensure uniqueness, specify a reverse DNS string that incorporates your company's domain and app name.

역방향 DNS 형식이 권장된다. 예제의 `com.devtechie.app`이 그 형식이다.

**하지만 결정적인 한계가 있다.**

> Although using a reverse DNS string is a best practice, it doesn't prevent other apps from registering the same scheme and handling the associated links. Use universal links instead of custom URL schemes to define links that are uniquely associated with your website.

**identifier가 고유해도 스킴 충돌을 막지 못한다.** 이름을 붙였을 뿐이지 소유권을 주장하는 것이 아니다. 실제 충돌 시 동작은 [스킴 해석과 충돌 문서](./url-scheme-resolution-and-conflicts.md)에서 다룬다.

용도를 정리하면 이렇다.

- URL 타입이 여러 개일 때 사람이 구분하기 위한 라벨
- macOS에서 Launch Services가 등록 정보를 관리할 때 참조
- iOS 딥링크 동작 자체에는 영향 없음

**생략해도 동작한다.** 다만 관례상 넣는다.

### ③ Role (`CFBundleTypeRole`)

> Choose a role for your app: either an **editor** role for URL schemes you define, or a **viewer** role for schemes your app adopts but doesn't define.

| 값 | 의미 |
| --- | --- |
| `Editor` | 내가 **정의한** 스킴. 읽고 수정한다 |
| `Viewer` | 남이 정의한 스킴을 **채택만** 한다. 보기만 한다 |
| `Shell` | 실행 셸 역할 (거의 안 씀) |
| `None` | 역할 없음 |

예제는 `Editor`다. `devtechie` 스킴을 이 앱이 직접 정의했으니 맞는 선택이다.

이 값은 **파일 타입(`CFBundleDocumentTypes`)에서 유래한 개념**이다. 문서를 편집할 수 있는 앱인지 보기만 하는 앱인지 구분하던 것이 URL 타입에도 그대로 들어왔다. 그래서 iOS의 URL 스킴 처리에서는 실질적 영향이 거의 없다. macOS에서 여러 앱이 같은 타입을 지원할 때 우선순위 판단에 참고될 수 있다.

**실무 기준: 내가 만든 스킴이면 `Editor`.**

### ④ Icon (`CFBundleURLIconFile`)

이 URL 타입을 나타낼 아이콘 파일 이름이다.

**iOS에서는 사실상 쓰이지 않는다.** macOS에서 Finder나 시스템 UI가 URL 타입을 표시할 때 쓰던 항목이다. iOS 앱이라면 비워 두면 된다. 예제의 Info.plist에도 없다.

### ⑤ Additional url type properties

Xcode UI가 제공하는 **자유 입력 영역**이다. 위 네 가지 외의 키를 직접 추가할 수 있다. 특정 SDK가 요구하는 커스텀 키를 넣는 정도로 쓰이고, 일반적인 딥링크 구현에는 필요 없다.

### 정리하면 — 실제로 필요한 것은 하나다

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>      <!-- 필수: 동작을 결정 -->
        <array><string>devtechie</string></array>

        <key>CFBundleURLName</key>          <!-- 관례: 라벨 -->
        <string>com.devtechie.app</string>

        <key>CFBundleTypeRole</key>         <!-- 관례: 보통 Editor -->
        <string>Editor</string>
    </dict>
</array>
```

`CFBundleURLSchemes`만 있으면 딥링크는 동작한다. 나머지는 문서화·관례의 영역이다.

### 참고 — 반대 방향의 키 `LSApplicationQueriesSchemes`

내 앱이 **다른 앱의 스킴을 열 수 있는지 확인**하려면 별도 등록이 필요하다.

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>kakaotalk</string>
</array>
```

`UIApplication.shared.canOpenURL(_:)`로 다른 앱 설치 여부를 확인할 때 쓴다. 등록하지 않은 스킴은 항상 `false`가 나온다. iOS 9부터 프라이버시 보호를 위해 도입된 제약이다.

`CFBundleURLTypes`가 "내가 받을 스킴", `LSApplicationQueriesSchemes`가 "내가 물어볼 스킴"이다.

### 받는 쪽 코드 — `onOpenURL`

SwiftUI에서는 `onOpenURL`이 진입점이다.

```swift
nonisolated func onOpenURL(perform action: @escaping (URL) -> ()) -> some View
```

> Use this view modifier to receive URLs in a particular scene within your app. The scene that SwiftUI routes the incoming URL to depends on the structure of your app, what scenes are active, and other configuration.

UIKit의 `application(_:open:options:)`에 대응하지만 훨씬 간단하다. Universal Links도 같은 modifier로 받는다.

> UI frameworks traditionally pass Universal Links to your app using an `NSUserActivity`. However, SwiftUI passes a Universal Link to your app directly as a URL, which you receive using this modifier.

**즉 커스텀 스킴이든 Universal Link든 `onOpenURL` 하나로 처리된다.** 나중에 Universal Links로 옮겨도 받는 코드는 그대로 쓸 수 있다는 뜻이다.

**주의할 점**이 있다. 예제는 `onOpenURL`을 `TextEditor`에 붙였다.

```swift
TextEditor(text: $text)
    .onOpenURL { url in ... }
```

동작하지만, 딥링크는 **화면 전체의 관심사**이므로 최상위 뷰나 `WindowGroup`에 붙이는 편이 안전하다. 조건부로 사라지는 뷰에 붙이면 그 뷰가 없을 때 URL을 놓칠 수 있다.

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in ... }   // 더 안전한 위치
        }
    }
}
```

## 학습 체크리스트

- [ ] `xcrun simctl openurl booted "devtechie://test"`로 딥링크를 실행해 본다.
- [ ] `devtechie://test?message=hello`로 쿼리를 붙이고 `url.query`에 무엇이 오는지 확인한다.
- [ ] `url.scheme`, `url.host`, `url.path`, `url.query`를 각각 출력해 구조를 확인한다.
- [ ] `URLComponents`로 `queryItems`를 파싱해 특정 파라미터만 꺼내 본다.
- [ ] `CFBundleURLSchemes`에서 `devtechie`를 지우고 딥링크가 동작하지 않는 것을 확인한다.
- [ ] `CFBundleURLName`을 지우고도 딥링크가 동작하는지 확인한다.
- [ ] `CFBundleTypeRole`을 `Viewer`로 바꿔도 동작에 차이가 없는지 확인한다.
- [ ] `CFBundleURLSchemes`에 스킴을 하나 더 추가해 둘 다 동작하는지 본다.
- [ ] `guard url.scheme == "devtechie"`를 지우고 다른 스킴 URL을 보내 본다.
- [ ] 잘못된 형식의 URL(`devtechie://`, `devtechie://unknown`)로 동작을 확인한다.
- [ ] `onOpenURL`을 `WindowGroup`으로 옮기고 동작이 같은지 비교한다.
- [ ] 앱이 완전히 종료된 상태에서 딥링크로 실행했을 때도 화면이 이동하는지 확인한다.
- [ ] `http://`처럼 예약 스킴을 등록하려 시도해 본다.
- [ ] Universal Links와 커스텀 스킴의 차이를 앱 미설치 상황 기준으로 설명한다.

## 공식 참고 자료

- [Apple: Defining a custom URL scheme for your app](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app)
- [Apple: Allowing apps and websites to link to your content](https://developer.apple.com/documentation/xcode/allowing-apps-and-websites-to-link-to-your-content)
- [Apple: CFBundleURLTypes](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleurltypes)
- [Apple: CFBundleURLSchemes](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleurltypes/cfbundleurlschemes)
- [Apple: CFBundleURLName](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleurltypes/cfbundleurlname)
- [Apple: CFBundleTypeRole](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleurltypes/cfbundletyperole)
- [Apple: CFBundleURLIconFile](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleurltypes/cfbundleurliconfile)
- [Apple: view.onOpenURL(perform:)](https://developer.apple.com/documentation/swiftui/view/onopenurl(perform:))
- [Apple: URLComponents](https://developer.apple.com/documentation/foundation/urlcomponents)
- [Apple: UIApplication.open(_:options:completionHandler:)](https://developer.apple.com/documentation/uikit/uiapplication/open(_:options:completionhandler:))
