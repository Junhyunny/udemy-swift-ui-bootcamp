# Swift 파일 명명 규칙 — `Type+Feature.swift`의 `+`는 무엇인가

`extension`의 적용 범위와 파일 관리는 [별도 문서](./extension-keyword.md)에 정리했다. 이 문서는 **파일 이름 규칙**에 집중한다.

## 질문이 나온 코드

`chapter-80/chapter-80/Utils/URL+Extensions.swift`

```swift
// TODO 파일 이름에 URL+Extensions 같이 +가 들어가는게 SwiftUI에선 일반적인 명명 규칙인가?
extension URL {
    func setQueries(_ queries: [String: String]) -> URL? { ... }
}
```

## 공부할 내용

### 결론 먼저

- **SwiftUI 규칙이 아니라 Apple 생태계 전반의 관례**다. Objective-C 시절부터 이어져 왔다.
- `+`는 **"이 타입에 이런 기능을 더했다"** 는 뜻이다.
- **공식 표준은 아니다.** Apple이 문서로 규정한 규칙이 아니라 커뮤니티 관례다.
- 다만 널리 통용되므로 따르는 편이 낫다.

### `+`는 어디서 왔나 — Objective-C 카테고리

Objective-C에는 **카테고리(category)** 라는 기능이 있었다. 기존 클래스에 메서드를 추가하는 문법으로, Swift `extension`의 조상이다.

```objc
// NSString+Trimming.h
@interface NSString (Trimming)
- (NSString *)trimmed;
@end
```

카테고리에는 **이름이 있었다.** 위 코드의 `(Trimming)`이 그것이다. 그래서 파일 이름도 `클래스명+카테고리명.h` 형태로 짓는 관례가 생겼다.

Swift extension은 이름이 없다. [extension 문서](./extension-keyword.md)에서 인용한 대로다.

> Extensions are similar to categories in Objective-C. **(Unlike Objective-C categories, Swift extensions don't have names.)**

이름이 없어졌지만 **파일 명명 관례는 남았다.** `URL+Extensions.swift`의 `+`가 그 유산이다.

### 어떻게 이름을 짓나 — 실무 관례

**① `Type+Feature.swift` — 기능이 명확할 때**

```text
URL+Queries.swift              쿼리 파라미터 조작
String+Validation.swift        검증 헬퍼
Date+Formatting.swift          날짜 포맷
Double+Currency.swift          통화 표시
View+CardStyle.swift           카드 스타일 modifier
```

**`Feature` 부분이 무엇을 더했는지 말해 주는 것이 핵심이다.** 파일을 열지 않고도 내용을 짐작할 수 있다.

**② `Type+Extensions.swift` — 잡다한 것을 모을 때**

이 예제가 이 형태다. 흔히 쓰이지만 **정보량이 적다는 단점**이 있다. "URL에 뭔가 추가했다"는 것 외에 알 수 있는 게 없다.

파일이 커지면 기능별로 나누는 편이 낫다.

```text
URL+Extensions.swift    →    URL+Queries.swift
                             URL+Validation.swift
```

이 프로젝트의 `URL+Extensions.swift`는 `setQueries` 하나뿐이므로 `URL+Queries.swift`가 더 정확하다.

**③ 프로토콜 준수는 준수마다 분리**

```text
Course.swift              저장 프로퍼티만
Course+Codable.swift      Codable 준수
Course+Sample.swift       미리보기용 샘플 데이터
```

chapter-34의 `DTCourse` 예제가 이 방식이었다.

**④ 타입 하나에 파일 하나 — 기본 원칙**

```text
Country.swift          struct Country
ExchangeRate.swift     struct ExchangeRate
ViewModel.swift        class ViewModel
```

이 프로젝트가 이 원칙을 따른다. **관련성이 아주 높은 작은 타입들은 함께 두어도 된다.**

```swift
// ExchangeRate.swift
struct ExchangeRate: Codable { ... }
struct DisplayRate: Identifiable { ... }    // ExchangeRate에서만 쓰인다
```

### 디렉터리 구조

이 프로젝트가 쓰는 방식이 널리 통용된다.

```text
chapter-80/
├── Models/          데이터 타입
├── Views/           화면
├── ViewModels/      뷰 로직
├── Services/        네트워크·저장소
├── Utils/           확장·헬퍼
└── Resources/       JSON, 이미지
```

**대안도 있다. 기능(feature) 단위 구조**다.

```text
Features/
├── ExchangeRate/
│   ├── ExchangeRateView.swift
│   ├── ExchangeRateViewModel.swift
│   └── ExchangeRateService.swift
└── Settings/
    ├── SettingsView.swift
    └── SettingsViewModel.swift
Shared/
├── Models/
└── Utils/
```

**프로젝트가 커지면 기능 단위가 유리하다.** 한 기능을 수정할 때 관련 파일이 한 폴더에 모여 있다. 반대로 작은 프로젝트에서는 타입 단위가 단순하다.

이 프로젝트 규모에서는 현재 구조가 적절하다.

### Apple이 공식 규정한 것은 무엇인가

**파일 이름 규칙은 공식 문서에 없다.** [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)는 **타입·메서드·파라미터 이름**을 다루고 파일 이름은 언급하지 않는다.

즉 `URL+Extensions.swift`는 **관례이지 규칙이 아니다.** 팀에서 다르게 정해도 문제없다. 다만 널리 통용되므로 새 코드에서 따르면 다른 개발자가 구조를 빠르게 파악한다.

**공식 규칙이 있는 것들**은 이렇다.

| 대상 | 규칙 |
| --- | --- |
| 타입 | `UpperCamelCase` |
| 함수·프로퍼티·변수 | `lowerCamelCase` |
| 열거형 케이스 | `lowerCamelCase` |
| 프로토콜 | 명사(능력이면 `-able`, `-ing`) |
| 파일 | **규정 없음** (관례상 담긴 타입 이름) |

### 흔히 보는 접미사들

파일 이름에 붙는 접미사도 관례가 있다.

| 접미사 | 내용 |
| --- | --- |
| `+Extensions` | 잡다한 확장 |
| `+Feature` | 특정 기능 확장 |
| `Tests` | 테스트 (`CountryTests.swift`) |
| `Mock`, `Stub` | 테스트 대역 (`MockService.swift`) |
| `Protocol` | 프로토콜 정의 (선택적) |

**`Manager`, `Helper`, `Util` 같은 이름은 신중히 쓴다.** 무엇을 하는지 드러나지 않아 온갖 코드가 모이는 창고가 되기 쉽다. 이 프로젝트의 `Utils/` 디렉터리도 파일이 늘어나면 성격별로 나누는 것이 좋다.

### 이 프로젝트에 적용하면

현재 구조는 대체로 관례를 잘 따른다. 다만 두 가지를 다듬을 수 있다.

**① `URL+Extensions.swift` → `URL+Queries.swift`**

`setQueries` 하나뿐이므로 기능이 이름에 드러나는 편이 낫다.

**② `Endpoint.swift`에 `AppConfig`가 함께 있다**

```swift
// Endpoint.swift
enum AppConfig { ... }      // API 키 관리
enum Endpoint { ... }       // URL 생성
```

두 타입의 역할이 다르므로 분리하는 편이 명확하다.

```text
Utils/AppConfig.swift      API 키
Utils/Endpoint.swift       URL 생성
```

**작은 프로젝트에서는 함께 두어도 무방하다.** 다만 `AppConfig`는 앱 전역 설정이므로 나중에 다른 값들이 추가될 가능성이 높다.

### 정리

```text
Type+Feature.swift
  Objective-C 카테고리(Type+CategoryName.h)에서 온 관례
  Swift extension은 이름이 없지만 파일 관례는 남았다
  SwiftUI 전용이 아니라 Apple 생태계 전반

공식 규칙은 아니다 — API Design Guidelines에 파일 이름 규정이 없다
다만 널리 통용되므로 따르는 편이 낫다

권장
  기능이 명확하면 +Feature (URL+Queries)
  잡다하면 +Extensions (정보량은 적다)
  프로토콜 준수는 준수마다 분리 (Course+Codable)
  타입 하나에 파일 하나가 기본
  Manager/Helper/Util 같은 이름은 창고가 되기 쉽다
```

## 학습 체크리스트

- [ ] `URL+Extensions.swift`를 `URL+Queries.swift`로 바꾸고 빌드되는지 확인한다 (파일명은 컴파일에 영향 없음).
- [ ] 파일 이름과 안에 든 타입 이름이 달라도 컴파일되는 것을 확인한다.
- [ ] `Endpoint.swift`에서 `AppConfig`를 별도 파일로 분리해 본다.
- [ ] `Course+Sample.swift`처럼 샘플 데이터를 분리해 본다.
- [ ] Objective-C 카테고리 문법을 찾아보고 `+` 관례의 유래를 확인한다.
- [ ] Swift API Design Guidelines에서 파일 이름 규정이 없는 것을 확인한다.
- [ ] 기능 단위 디렉터리 구조로 재배치해 보고 타입 단위와 비교한다.
- [ ] `Utils/`에 파일이 여러 개 쌓였을 때 어떻게 나눌지 계획해 본다.

## 공식 참고 자료

- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- [Swift 공식 문서: Extensions](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/extensions/)
- [Swift 공식 문서: Lexical Structure — Identifiers](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/lexicalstructure/#Identifiers)
- [Apple: Managing files and folders in your Xcode project](https://developer.apple.com/documentation/xcode/managing-files-and-folders-in-your-xcode-project)
- [Apple: Organizing your code with local packages](https://developer.apple.com/documentation/xcode/organizing-your-code-with-local-packages)
- [Apple: Adding files to your Xcode project](https://developer.apple.com/documentation/xcode/adding-files-to-your-project)
