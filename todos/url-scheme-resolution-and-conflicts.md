# 브라우저가 앱을 찾아가는 원리와 스킴 충돌

딥링크의 용도와 Info.plist 설정 항목은 [별도 문서](./deep-link-and-url-scheme.md)에 있다. 이 문서는 **iOS가 어떻게 앱을 찾아내는가**와 **같은 스킴이 겹치면 어떻게 되는가**를 다룬다.

## 질문이 나온 코드

`chapter-51/chapter-51/ContentView.swift`

시뮬레이터 Safari에서 `devtechie://test`를 입력하니 `onOpenURL`이 실행됐다.

```swift
.onOpenURL { url in
    latestURL = url
    coordinator.handleDeepLinkURL(url)
}
```

iOS가 자동으로 매칭되는 앱을 찾아 주는 것으로 보인다. 그 원리는 무엇이고, 같은 스킴을 가진 앱이 둘이면 어떻게 되는가?

## 1부 — 앱을 찾아가는 원리

### 짐작이 맞다 — 시스템이 스킴으로 앱을 찾는다

전체 흐름은 이렇다.

```text
① 앱 설치 시점
   iOS가 앱 번들의 Info.plist를 읽는다
        ↓
   CFBundleURLTypes의 CFBundleURLSchemes 값을 수집
        ↓
   시스템 데이터베이스에 "devtechie → 이 앱" 등록
   (Launch Services가 관리)

② 사용자가 devtechie://test 입력
        ↓
   Safari가 URL 파싱 → scheme = "devtechie"
        ↓
   Safari는 http/https만 자기가 처리한다
   모르는 스킴이므로 시스템에 넘긴다
        ↓
③ 시스템(Launch Services)이 데이터베이스 조회
        ↓
   "devtechie"를 등록한 앱을 찾음
        ↓
④ 해당 앱을 실행하거나 포그라운드로 가져옴
        ↓
   URL을 앱에 전달
        ↓
⑤ SwiftUI가 활성 scene으로 라우팅
        ↓
   onOpenURL 클로저 호출
```

핵심은 **③의 조회 테이블**이다. 앱이 설치될 때 미리 등록해 두었다가, URL이 들어오면 스킴 이름으로 찾는다. 실시간으로 앱들을 검색하는 것이 아니라 **설치 시점에 만들어진 색인**을 보는 것이다.

Apple의 설명이 ④를 확인해 준다.

> When another app opens a URL containing your custom scheme, the system launches your app, if necessary, and brings it to the foreground. The system delivers the URL to your app by calling your app delegate's `application(_:open:options:)` method.

`if necessary`가 중요하다. 앱이 꺼져 있으면 실행하고, 백그라운드에 있으면 포그라운드로 올린다.

### 등록은 설치 시점에 일어난다

이 성질에서 실무적 결론이 나온다.

- **Info.plist를 고쳤다면 앱을 다시 설치해야 한다.** 코드만 다시 빌드해서는 반영되지 않을 수 있다. 시뮬레이터에서 스킴이 안 먹으면 앱을 지우고 다시 설치해 본다.
- **앱이 삭제되면 등록도 사라진다.**
- **앱이 설치되어 있지 않으면 아무 일도 일어나지 않는다.** Safari에서 `devtechie://test`를 입력해도 "주소를 열 수 없습니다" 수준의 반응만 나온다. 이것이 Universal Links가 권장되는 큰 이유다 — 앱이 없으면 웹페이지로 대체된다.

### Safari가 처리하지 않고 넘기는 이유

브라우저는 자기가 아는 스킴만 직접 처리한다.

| 스킴 | 처리 주체 |
| --- | --- |
| `http`, `https` | Safari 자신 |
| `mailto`, `tel`, `sms`, `facetime` | 시스템 앱 |
| `devtechie` | **등록된 서드파티 앱** |

> Some URL schemes are reserved for system use. The system directs well-known types of URLs to the corresponding system apps, and well-known http–based URLs to specific apps such as Maps, YouTube, and Music.

chapter-49에서 `mailto:`를 열어 봤던 것이 두 번째 줄에 해당한다.

### ⑤ SwiftUI로 전달되는 부분

UIKit이라면 앱 델리게이트의 `application(_:open:options:)`가 받는다. SwiftUI는 `onOpenURL`이 그 자리를 대신한다.

> Use this view modifier to receive URLs in a particular scene within your app. **The scene that SwiftUI routes the incoming URL to depends on the structure of your app, what scenes are active, and other configuration.**

강조한 부분이 주의할 지점이다. **어느 scene이 받을지는 앱 구조와 활성 상태에 달려 있다.** 그래서 `onOpenURL`을 조건부로 사라지는 뷰에 붙이면 URL을 놓칠 수 있다.

예제는 `TextEditor`에 붙어 있다.

```swift
TextEditor(text: $text)
    .onOpenURL { url in ... }
```

지금은 `TextEditor`가 항상 화면에 있어서 동작하지만, 딥링크는 화면 전체의 관심사이므로 `WindowGroup` 쪽으로 올리는 것이 안전하다.

**보내는 쪽에서 알 수 있는 정보**도 있다. UIKit 기준으로는 옵션 딕셔너리에서 발신 앱을 확인할 수 있다.

```swift
// Determine who sent the URL.
let sendingAppID = options[.sourceApplication]
print("source application = \(sendingAppID ?? "Unknown")")
```

SwiftUI의 `onOpenURL`은 URL만 주므로 이 정보를 얻으려면 `UIApplicationDelegateAdaptor`를 써야 한다.

### Universal Links는 원리가 다르다

같은 딥링크라도 경로가 다르다.

```text
커스텀 스킴
  설치 시 Info.plist 읽기 → 로컬 DB 등록 → 스킴으로 조회

Universal Links
  설치 시 앱의 Associated Domains 확인
       ↓
  해당 도메인의 https://도메인/.well-known/apple-app-site-association 다운로드
       ↓
  파일에 이 앱의 ID가 있는지 검증  ← 서버가 승인해야 성립
       ↓
  검증 통과한 경로만 앱으로 연결
```

> When someone installs your app, the system checks a file stored on your web server to verify that your website allows your app to open URLs on its behalf. Only you can store this file on your server, securing the association of your website and your app.

**서버 검증이 있느냐 없느냐**가 두 방식의 근본적 차이이고, 2부의 충돌 문제로 직결된다.

한 가지 더 알아둘 동작이 있다.

> When a user browses your website in Safari and taps a universal link in the same domain, the system opens that link in Safari, respecting the user's most likely intent to continue within the browser. If the user taps a universal link in a different domain, the system opens the link in your app.

같은 도메인 안에서의 이동은 앱으로 가지 않는다. Universal Links를 테스트할 때 "왜 앱이 안 열리지" 하는 흔한 원인이다.

## 2부 — 스킴이 겹치면 어떻게 되는가

질문의 두 케이스를 각각 본다.

### 케이스 1 — 서로 다른 앱이 같은 스킴을 등록

**결론: 에러도 아니고 설치 거부도 아니다. 어느 앱이 열릴지 정해지지 않는다.**

Apple의 답이 명확하다.

> **Note:** If multiple apps register the same scheme, **the app the system targets is undefined**. There's no mechanism to change the app or to change the order apps appear in a Share sheet.

세 가지를 확인할 수 있다.

- **설치는 정상적으로 된다.** 스킴 충돌로 설치가 막히지 않는다.
- **런타임 에러도 없다.** 그냥 둘 중 하나가 열린다.
- **어느 쪽이 열릴지 명세되어 있지 않고, 바꿀 방법도 없다.** 사용자에게 선택지를 주는 UI도 없다.

일반적으로 관찰되는 경향(먼저 설치된 앱이 우선 등)이 있지만 **문서화된 보장이 아니다.** iOS 버전에 따라 달라질 수 있으므로 의존하면 안 된다.

**identifier를 고유하게 지어도 막지 못한다.**

> Although using a reverse DNS string is a best practice, **it doesn't prevent other apps from registering the same scheme** and handling the associated links.

`com.devtechie.app`이라는 `CFBundleURLName`은 라벨일 뿐 소유권 주장이 아니다.

**이것이 왜 보안 문제인가.** 악의적인 앱이 유명 앱의 스킴을 똑같이 등록하면, OAuth 콜백 같은 민감한 URL을 가로챌 수 있다. `myapp://oauth/callback?code=abc123`의 인증 코드가 다른 앱으로 갈 수 있다는 뜻이다. Apple이 Universal Links를 강하게 권하는 이유가 여기 있다.

> Use universal links instead of custom URL schemes to define links that are uniquely associated with your website.

**실무 대응**

- 스킴 이름을 충분히 고유하게 짓는다. `devtechie`처럼 브랜드명을 쓰고, `app`·`test`·`open` 같은 일반 단어를 피한다
- 민감한 데이터를 커스텀 스킴으로 주고받지 않는다
- 받은 URL을 반드시 검증한다 ([보안 경고](./deep-link-and-url-scheme.md) 참조)
- 중요한 링크는 Universal Links로 옮긴다

### 케이스 2 — 하나의 앱이 같은 스킴을 중복 선언

**결론: 문제없이 동작한다. 중복은 무시된다.**

`CFBundleURLTypes`는 배열이므로 이런 구조가 가능하다.

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.devtechie.app</string>
        <key>CFBundleURLSchemes</key>
        <array><string>devtechie</string></array>
    </dict>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.devtechie.legacy</string>
        <key>CFBundleURLSchemes</key>
        <array><string>devtechie</string></array>   <!-- 같은 스킴 -->
    </dict>
</array>
```

같은 앱 안에서의 중복이므로 **결국 같은 앱으로 라우팅된다.** 어느 항목이 매칭되든 목적지가 하나라 결과가 같다. 빌드 에러도 설치 실패도 없다.

같은 배열 안에 중복을 넣는 경우도 마찬가지다.

```xml
<array>
    <string>devtechie</string>
    <string>devtechie</string>    <!-- 중복 -->
</array>
```

무해하지만 의미도 없다. 정리해 두는 편이 낫다.

**실제로 유용한 경우**는 여러 스킴을 각각 다른 용도로 등록할 때다.

```xml
<key>CFBundleURLSchemes</key>
<array>
    <string>devtechie</string>        <!-- 운영 -->
    <string>devtechie-dev</string>    <!-- 개발 빌드 -->
    <string>devtechie-oauth</string>  <!-- 인증 콜백 전용 -->
</array>
```

`onOpenURL`에서 스킴별로 분기하면 된다. 예제의 `guard url.scheme == "devtechie"`를 확장하는 형태다.

### 정리

| 상황 | 결과 |
| --- | --- |
| 다른 앱이 같은 스킴 등록 | 설치·실행 모두 정상. **어느 앱이 열릴지 미정의** |
| 같은 앱이 같은 스킴 중복 선언 | 정상 동작. 중복은 실질적으로 무시됨 |
| 앱이 설치되지 않음 | 아무 일도 일어나지 않음 |
| 예약 스킴(`http` 등) 등록 시도 | 시스템이 우선, 내 앱으로 오지 않음 |

```text
커스텀 스킴은 "선착순 등록제"가 아니라 "누구나 등록 가능"이다.
고유성이 보장되지 않는다는 것이 설계상의 한계이고,
그래서 Apple은 Universal Links를 권한다.
```

### Universal Links는 이 문제가 없다

같은 상황을 Universal Links로 옮기면 이렇게 된다.

- 다른 앱이 `https://devtechie.com/*`을 가로채려 해도, **서버의 `apple-app-site-association` 파일에 그 앱 ID가 없으면 연결되지 않는다**
- 도메인 소유자만 그 파일을 올릴 수 있으므로 소유권이 검증된다
- 앱이 없으면 웹으로 대체되어 사용자 경험이 끊기지 않는다

받는 코드는 그대로 `onOpenURL`이므로, 나중에 마이그레이션하더라도 `handleDeepLinkURL` 로직은 재사용할 수 있다.

## 학습 체크리스트

- [ ] `xcrun simctl openurl booted "devtechie://test"`로 앱이 실행되는지 확인한다.
- [ ] 앱을 완전히 삭제한 뒤 같은 URL을 열어 아무 일도 없는 것을 확인한다.
- [ ] Info.plist의 스킴을 바꾸고 **재설치 없이** 빌드했을 때 반영되는지 확인한다.
- [ ] 앱을 지우고 다시 설치한 뒤 새 스킴이 동작하는지 확인한다.
- [ ] 앱이 완전히 종료된 상태와 백그라운드 상태에서 각각 딥링크를 열어 차이를 본다.
- [ ] 같은 스킴을 쓰는 테스트 앱을 하나 더 만들어 어느 쪽이 열리는지 관찰한다.
- [ ] 그 상태에서 설치 순서를 바꿔 결과가 달라지는지 확인한다 (보장되지 않음을 체감).
- [ ] `CFBundleURLTypes`에 같은 스킴을 가진 항목을 두 개 넣고 정상 동작하는지 확인한다.
- [ ] 스킴 배열에 `devtechie-dev`를 추가하고 두 스킴 모두 동작하는지 본다.
- [ ] `onOpenURL`에서 스킴별로 분기하는 코드를 작성한다.
- [ ] `onOpenURL`을 조건부 뷰(`if` 안)에 넣고 URL을 놓치는 상황을 재현해 본다.
- [ ] `http://example.com`을 Safari에 입력해 내 앱으로 오지 않는 것을 확인한다.
- [ ] OAuth 콜백을 커스텀 스킴으로 처리할 때의 위험을 한 문단으로 설명한다.
- [ ] Universal Links의 `apple-app-site-association` 파일 구조를 문서에서 찾아본다.

## 공식 참고 자료

- [Apple: Defining a custom URL scheme for your app](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app)
- [Apple: Allowing apps and websites to link to your content](https://developer.apple.com/documentation/xcode/allowing-apps-and-websites-to-link-to-your-content)
- [Apple: Supporting associated domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains)
- [Apple: Handling universal links](https://developer.apple.com/documentation/xcode/handling-universal-links)
- [Apple: CFBundleURLTypes](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleurltypes)
- [Apple: view.onOpenURL(perform:)](https://developer.apple.com/documentation/swiftui/view/onopenurl(perform:))
- [Apple: UIApplication.open(_:options:completionHandler:)](https://developer.apple.com/documentation/uikit/uiapplication/open(_:options:completionhandler:))
- [Apple: UIApplicationDelegate.application(_:open:options:)](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/application(_:open:options:))
