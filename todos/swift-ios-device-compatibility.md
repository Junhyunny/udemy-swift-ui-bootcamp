# Swift · iOS · 기기 버전 호환성을 확인하는 방법

## 질문이 나온 배경

`chapter-57/chapter-57/ContentView.swift`에서 `NavigationStack`이 언제 등장했는지 묻다 보면 자연스럽게 따라오는 질문이다. Swift 버전, iOS 버전, 기기 지원 범위가 어떻게 얽혀 있고, 어디서 확인하는가.

## 공부할 내용

### 먼저 개념 정리 — 네 가지 버전은 서로 다른 축이다

가장 흔한 혼동이 "Swift 버전"과 "iOS 버전"을 같은 것으로 보는 것이다. 실제로는 축이 넷이고 각각 따로 움직인다.

| 축 | 무엇을 정하나 | 예 |
| --- | --- | --- |
| **Swift 언어 버전** | 문법과 컴파일러 기능 | `async/await`, 매크로, `Sendable` |
| **SDK 버전** | 쓸 수 있는 프레임워크 API | `NavigationStack`, `@Observable` |
| **배포 타겟(Deployment Target)** | 앱이 지원하는 최소 OS | iOS 16.0 |
| **기기** | 해당 OS를 올릴 수 있는 하드웨어 | iPhone 11은 iOS 26까지 |

**SwiftUI의 새 타입이 언제 쓸 수 있는지는 Swift 버전이 아니라 배포 타겟이 정한다.** `NavigationStack`은 iOS 16.0, `@Observable`은 iOS 17.0, `ImageResource`는 iOS 17.0이다. Swift 6로 컴파일해도 배포 타겟이 iOS 15면 이들을 쓸 수 없다.

반대도 성립한다. Swift의 **문법** 기능은 대체로 컴파일러가 처리하므로 낮은 배포 타겟에서도 쓸 수 있다. 다만 예외가 있다 — `async/await`는 런타임 지원이 필요해 iOS 13 이상이어야 한다.

```text
Xcode 버전 ─┬─ Swift 컴파일러 버전을 결정
            ├─ 포함된 SDK 버전을 결정
            └─ 지원 가능한 배포 타겟 범위를 결정
                    ↓
            배포 타겟이 "어떤 API를 쓸 수 있는가"를 결정
                    ↓
            그 OS를 지원하는 기기가 "누가 쓸 수 있는가"를 결정
```

### ① Xcode ↔ Swift ↔ SDK ↔ 배포 타겟 — 가장 중요한 표

**[Apple: SDK and system requirements (Xcode Support)](https://developer.apple.com/support/xcode/)**

이 한 페이지가 질문의 핵심을 거의 다 담고 있다. 표의 열이 이렇게 구성된다.

| 열 | 의미 |
| --- | --- |
| Xcode Version | Xcode 버전 |
| Supported macOS Versions | 이 Xcode를 돌리는 데 필요한 macOS |
| SDKs | 포함된 SDK 버전 |
| **Deployment Targets** | **지원 가능한 최소·최대 OS 범위** |
| Device Support | 실기기 디버깅 가능 범위 |
| Simulator | 시뮬레이터 OS 범위 |
| **Swift** | **Swift 컴파일러 버전과 언어 모드** |

예를 들어 Xcode 26.6은 Swift 6.3 컴파일러를 쓰고 iOS 26.5 SDK를 포함한다. Xcode 27 beta는 Swift 6.4에 iOS 27 SDK, 배포 타겟은 iOS 15–27을 지원한다.

**여기서 읽어야 할 것 두 가지다.**

- "이 Xcode로 iOS 몇까지 지원하는 앱을 만들 수 있나" → Deployment Targets 열
- "이 Xcode의 Swift 버전은 몇인가" → Swift 열

배포 타겟에 **하한**이 있다는 점도 중요하다. Xcode 27이 iOS 15부터 지원한다면, iOS 14를 지원해야 하는 앱은 더 낮은 Xcode를 써야 한다.

### ② 특정 API가 언제 등장했는지 — 문서에서 직접 확인

가장 확실하고 빠른 방법이다. **Apple 개발자 문서의 각 심볼 페이지 우측**에 availability가 표시된다.

```text
NavigationStack
iOS 16.0+  iPadOS 16.0+  macOS 13.0+  tvOS 16.0+  watchOS 9.0+
```

deprecated된 것은 이렇게 나온다.

```text
NavigationView
iOS 13.0–27.0  Deprecated
```

**Xcode 안에서 확인하는 방법**도 있다.

- 심볼에 커서를 두고 **Quick Help**(⌥클릭)를 열면 availability가 보인다
- 심볼 정의로 점프(⌃⌘클릭)하면 `@available(iOS 16.0, *)` 어트리뷰트를 직접 볼 수 있다

**코드로 분기**할 때는 `#available`을 쓴다.

```swift
if #available(iOS 16.0, *) {
    NavigationStack { content }
} else {
    NavigationView { content }
}
```

타입이나 함수 전체에 조건을 걸 때는 `@available`을 쓴다.

```swift
@available(iOS 17.0, *)
struct ModernView: View { /* ... */ }
```

### ③ 어떤 기기가 어떤 iOS를 지원하는가

**[Apple Support: iPhone models compatible with iOS 26](https://support.apple.com/guide/iphone/iphe3fa5df43/ios)**

iOS 버전마다 별도 페이지가 있고, URL의 버전 부분을 바꾸면 과거 버전도 볼 수 있다.

- [iOS 17 호환 모델](https://support.apple.com/guide/iphone/iphone-models-compatible-with-ios-17-iphe3fa5df43/17.0/ios/17.0)
- [iOS 16 호환 모델](https://support.apple.com/guide/iphone/supported-models-iphe3fa5df43/16.0/ios/16.0)

**[Apple Support: Identify your iPhone model](https://support.apple.com/en-us/108044)** 은 기기 식별용이다.

**실무에서 이 표를 읽는 방향**이 중요하다. "내 앱의 배포 타겟을 iOS 16으로 정하면 어떤 기기가 잘려 나가는가"를 역으로 확인하는 용도다. iOS 16은 iPhone 8 이상을 지원하므로, iPhone 7 이하 사용자는 앱을 설치할 수 없게 된다.

다만 **기기 지원 목록보다 실제 사용자 분포가 더 중요하다.** 앱 스토어 커넥트의 앱 분석에서 실제 사용자의 OS 버전 분포를 볼 수 있다. 하위 버전 사용자가 1%도 안 된다면 지원을 끊는 판단이 쉬워진다.

### ④ Swift 언어 자체의 변화

**[Swift.org](https://www.swift.org/)** 가 언어의 공식 홈이다.

| 자료 | 용도 |
| --- | --- |
| [The Swift Programming Language](https://docs.swift.org/swift-book/) | 언어 공식 문서. 문법의 기준 |
| [Swift Evolution](https://www.swift.org/swift-evolution/) | **어떤 기능이 왜 들어왔는지** 제안서 목록 |
| [swift-evolution GitHub](https://github.com/swiftlang/swift-evolution/tree/main/proposals) | 제안서 원문 |
| [Swift Blog](https://www.swift.org/blog/) | 릴리스 소식 |

**Swift Evolution이 특히 유용하다.** "이 문법은 왜 이렇게 됐나"를 알고 싶을 때 답이 있다. 이 저장소의 문서에서도 [SE-0086 (NS 접두사 제거)](./ns-prefix-foundation-classes.md)와 [SE-0307 (CGFloat↔Double)](./coregraphics-types-and-cgfloat.md)을 근거로 인용했다.

제안서는 상태와 도입 버전이 표시된다.

```text
SE-0307: Allow interchangeable use of CGFloat and Double types
Status: Implemented (Swift 5.5)
```

### ⑤ 릴리스 노트 — 무엇이 바뀌었는지

| 자료 | 용도 |
| --- | --- |
| [Xcode Release Notes](https://developer.apple.com/documentation/xcode-release-notes) | Xcode 버전별 변경, 알려진 이슈 |
| [iOS & iPadOS Release Notes](https://developer.apple.com/documentation/ios-ipados-release-notes) | SDK 변경 사항 |
| [Apple Developer Releases](https://developer.apple.com/news/releases/) | 최신 릴리스 소식 |

**"Deprecations" 섹션을 특히 볼 만하다.** 무엇이 사라질 예정인지 미리 알 수 있다.

### 공부 순서 제안

이 자료들을 언제 보면 좋은지 정리하면 이렇다.

**1단계 — 지금 당장 필요한 것**

- API가 언제 등장했는지: **문서 페이지의 availability** 또는 Xcode Quick Help
- 프로젝트 설정: Xcode의 **Minimum Deployments** 항목이 현재 배포 타겟이다

**2단계 — 프로젝트를 시작할 때**

- [SDK and system requirements](https://developer.apple.com/support/xcode/)에서 Xcode와 배포 타겟 조합을 확인
- [기기 호환 목록](https://support.apple.com/guide/iphone/iphe3fa5df43/ios)으로 잘려 나가는 사용자 범위 파악

**3단계 — 깊이 이해하고 싶을 때**

- [Swift Evolution](https://www.swift.org/swift-evolution/)에서 관심 있는 기능의 제안서를 읽는다
- WWDC 세션 영상 — 새 API의 의도와 사용법을 설계자가 직접 설명한다
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/) — API가 아니라 "어떻게 써야 하는가"

**4단계 — 유지보수 단계**

- 매년 WWDC 직후 릴리스 노트의 deprecation 확인
- 배포 타겟을 올릴 시점 판단 (사용자 분포 기준)

### 정리

```text
"이거 언제부터 쓸 수 있어?"
    → 문서 페이지 availability / Xcode Quick Help

"이 Xcode로 어디까지 지원 가능해?"
    → developer.apple.com/support/xcode

"배포 타겟을 올리면 누가 못 쓰게 돼?"
    → support.apple.com 기기 호환 목록 + App Store Connect 사용자 분포

"이 Swift 문법은 왜 이래?"
    → swift.org/swift-evolution

"뭐가 없어질 예정이야?"
    → Xcode Release Notes의 Deprecations
```

## 학습 체크리스트

- [ ] Xcode에서 프로젝트의 Minimum Deployments 값을 확인한다.
- [ ] `NavigationStack`에 ⌥클릭해 Quick Help의 availability를 확인한다.
- [ ] `NavigationStack` 정의로 점프해 `@available` 어트리뷰트를 직접 본다.
- [ ] 배포 타겟을 iOS 15로 낮추고 어떤 API들이 에러를 내는지 목록을 만든다.
- [ ] `#available(iOS 16.0, *)` 분기를 작성해 컴파일이 통과하는지 확인한다.
- [ ] [SDK and system requirements](https://developer.apple.com/support/xcode/)에서 현재 쓰는 Xcode의 Swift 버전을 찾는다.
- [ ] 같은 표에서 배포 타겟의 **하한**이 얼마인지 확인한다.
- [ ] iOS 16이 지원하는 최소 iPhone 모델을 찾아본다.
- [ ] `swift --version`을 터미널에서 실행해 컴파일러 버전을 확인한다.
- [ ] Swift Evolution에서 `async/await` 제안서(SE-0296)를 찾아 도입 버전을 확인한다.
- [ ] 관심 있는 API 하나를 골라 WWDC 세션을 찾아본다.
- [ ] Xcode Release Notes에서 Deprecations 섹션을 훑어본다.

## 공식 참고 자료

**버전·호환성**

- [Apple: SDK and system requirements (Xcode)](https://developer.apple.com/support/xcode/) — Xcode·Swift·SDK·배포 타겟 대응표
- [Apple: Xcode Release Notes](https://developer.apple.com/documentation/xcode-release-notes)
- [Apple: iOS & iPadOS Release Notes](https://developer.apple.com/documentation/ios-ipados-release-notes)
- [Apple Developer: Releases](https://developer.apple.com/news/releases/)

**기기**

- [Apple Support: iPhone models compatible with iOS 26](https://support.apple.com/guide/iphone/iphe3fa5df43/ios)
- [Apple Support: iPhone models compatible with iOS 17](https://support.apple.com/guide/iphone/iphone-models-compatible-with-ios-17-iphe3fa5df43/17.0/ios/17.0)
- [Apple Support: Identify your iPhone model](https://support.apple.com/en-us/108044)

**Swift 언어**

- [Swift.org](https://www.swift.org/)
- [The Swift Programming Language](https://docs.swift.org/swift-book/)
- [Swift Evolution](https://www.swift.org/swift-evolution/)
- [swift-evolution proposals (GitHub)](https://github.com/swiftlang/swift-evolution/tree/main/proposals)
- [Swift Blog](https://www.swift.org/blog/)

**API 문서**

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [Apple: SwiftUI](https://developer.apple.com/documentation/swiftui)
- [Apple: Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Apple: WWDC Videos](https://developer.apple.com/videos/)
