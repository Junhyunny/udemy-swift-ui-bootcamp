# `URLComponents`로 URL 만들기 — 왜 `self`가 아니라 `components.url`인가

## 질문이 나온 코드

`chapter-80/chapter-80/Utils/URL+Extensions.swift`

```swift
extension URL {
    func setQueries(_ queries: [String: String]) -> URL? {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: true)
        components?.queryItems = queries.map { URLQueryItem(name: $0.key, value: $0.value) }
        // TODO, 왜 self 객체에 components 를 설정 후 self 를 반환하는게 아니라,
        //       components 의 url 객체를 반환하는거야?
        return components?.url
    }
}
```

## 공부할 내용

### 결론 먼저

- **`URL`에는 쿼리를 수정하는 API가 없다.** 그래서 `self`에 설정할 방법이 자체가 없다.
- `URL`은 **문자열에 가까운 값**이고, `URLComponents`는 **그것을 부품으로 분해한 편집기**다.
- 따라서 흐름이 `URL → URLComponents(편집) → URL`이 될 수밖에 없다.
- **이 패턴은 매우 일반적이다.** Swift에서 URL에 쿼리를 붙이는 표준 방법이다.

### `URL`과 `URLComponents`는 역할이 다르다

| | `URL` | `URLComponents` |
| --- | --- | --- |
| 성격 | **완성된 주소** | **부품 조립기** |
| 프로퍼티 | 대부분 **읽기 전용** | **읽기·쓰기 가능** |
| `scheme` | `let`처럼 읽기만 | `var` — 수정 가능 |
| `queryItems` | **없다** | `var` — 수정 가능 |
| 인코딩 | 이미 완료된 상태 | 조립 시 자동 처리 |

`URL`의 프로퍼티를 보면 알 수 있다.

```swift
let url = URL(string: "https://api.example.com/v1/latest")!
url.scheme        // "https"  — 읽기만
url.host          // "api.example.com"  — 읽기만
url.query         // nil  — 읽기만
// url.queryItems  ← 애초에 존재하지 않는다
```

**`URL`은 쿼리를 "읽을" 수는 있어도 "쓸" 수는 없다.** `query` 프로퍼티도 `String?`을 읽기 전용으로 줄 뿐이다.

그래서 질문의 "self에 components를 설정"이 **문법적으로 불가능하다.** 설정할 프로퍼티가 없다.

### `URLComponents`가 하는 일

URL을 구성 요소로 쪼개 각각을 수정할 수 있게 해 준다.

```swift
var components = URLComponents(url: url, resolvingAgainstBaseURL: true)

components?.scheme        // "https"      — var
components?.host          // "api.example.com"  — var
components?.path          // "/v1/latest"  — var
components?.queryItems    // nil           — var  ← 수정 가능
components?.port          // nil           — var
components?.fragment      // nil           — var
```

수정한 뒤 `url` 프로퍼티로 다시 조립한다.

```swift
components?.url           // URL?  ← 조립 결과
```

**`url`이 옵셔널인 이유**가 있다. 수정한 결과가 유효한 URL이 아닐 수 있기 때문이다.

```swift
var c = URLComponents()
c.host = "example.com"
c.url                     // scheme이 없어 nil일 수 있다
```

### 왜 이 흐름이 자연스러운가 — 값 타입

`URL`과 `URLComponents`는 모두 `struct`, 즉 **값 타입**이다. [struct와 class](./struct-vs-class.md)에서 다룬 성질이 적용된다.

값 타입은 **제자리에서 바꾸는 것보다 새 값을 만드는 것**이 자연스럽다.

```swift
// 값 타입의 일반적 패턴
let newArray = oldArray.map { ... }        // 원본은 그대로
let newString = oldString.uppercased()     // 원본은 그대로
let newURL = url.appendingPathComponent("v1")   // 원본은 그대로
```

`setQueries`도 같은 방식이다. **원본 `self`를 바꾸지 않고 새 `URL`을 돌려준다.** 함수 이름이 `setQueries`인 것이 오히려 오해를 준다 — 실제로는 설정이 아니라 **새 URL 생성**이다.

이름을 Swift 관례에 맞추면 이렇게 된다.

```swift
// 새 값을 돌려주므로 -ing 형태
func addingQueries(_ queries: [String: String]) -> URL?
func settingQueries(_ queries: [String: String]) -> URL?
```

[API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)의 원칙이다. **부수 효과가 없으면 명사구나 `-ing`/`-ed` 형태**를 쓴다. `URL`의 기존 API가 그 예다.

```swift
url.appendingPathComponent("v1")     // 새 값 반환 → -ing
url.appendPathComponent("v1")        // 제자리 수정 → 동사 원형 (mutating)
```

### 실제로 `URL`에도 mutating API가 있다

**쿼리는 없지만 경로는 있다.** iOS 16부터 추가됐다.

```swift
var url = URL(string: "https://api.example.com")!
url.append(path: "v1/latest")                    // mutating
url.append(queryItems: [URLQueryItem(name: "base", value: "EUR")])   // ← 있다!
```

**`append(queryItems:)`가 존재한다.** 그래서 이 함수를 이렇게 쓸 수도 있다.

```swift
extension URL {
    func addingQueries(_ queries: [String: String]) -> URL {
        var copy = self
        copy.append(queryItems: queries.map { URLQueryItem(name: $0.key, value: $0.value) })
        return copy
    }
}
```

**옵셔널이 사라지는 것이 이점**이다. `URLComponents` 경로는 `URL?`을 돌려주지만 이쪽은 `URL`이다. 호출부에서 강제 언래핑이 필요 없어진다.

이 프로젝트가 실제로 그 문제를 겪고 있다.

```swift
// ExchangeRateService.swift
return urlSession(ExchangeRate.self, with: Endpoint.withSymbols.url!)
//                                                              ↑ 강제 언래핑
```

**`URLComponents` 방식이 여전히 필요한 경우**도 있다. 경로나 호스트를 함께 바꿔야 할 때, 기존 쿼리를 교체(추가가 아니라)해야 할 때다. 이 함수는 `queryItems`에 대입하므로 **교체** 동작이고, `append`는 **추가**다.

```swift
// 교체 — 기존 쿼리를 버린다
components?.queryItems = [...]

// 추가 — 기존 쿼리에 덧붙인다
url.append(queryItems: [...])
```

### 이 패턴이 일반적인가 — 그렇다

질문의 "일반적인 방법인지"에 답하면 **매우 일반적이다.** `URLComponents`로 URL을 조립하는 것은 Swift에서 권장되는 방식이다.

**문자열 연결로 URL을 만드는 것보다 안전하다.**

```swift
// ⚠️ 위험 — 인코딩을 직접 해야 한다
let url = URL(string: "https://api.example.com/search?q=" + query)

// ✅ URLComponents가 인코딩을 처리한다
var c = URLComponents(string: "https://api.example.com/search")!
c.queryItems = [URLQueryItem(name: "q", value: query)]
let url = c.url
```

`query`에 공백이나 `&`, 한글이 들어가면 첫 번째는 깨지거나 `nil`이 된다. `URLComponents`는 퍼센트 인코딩을 자동으로 해 준다.

chapter-61에서도 이 원칙이 나왔다. [딥링크 문서](./deep-link-and-url-scheme.md)에서 인용한 Apple의 권고다.

> To ensure the URL is parsed correctly, use `URLComponents` APIs to extract the components.

### 개선 여지

**① 옵셔널 체인이 장황하다**

```swift
var components = URLComponents(url: self, resolvingAgainstBaseURL: true)
components?.queryItems = ...
return components?.url
```

`guard`로 풀면 읽기 쉬워진다.

```swift
func addingQueries(_ queries: [String: String]) -> URL? {
    guard var components = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
        return nil
    }
    components.queryItems = queries.map { URLQueryItem(name: $0.key, value: $0.value) }
    return components.url
}
```

[guard 문서](./guard-keyword.md)에서 다룬 대로 바인딩이 이후까지 살아남아 `?`가 사라진다.

**② 딕셔너리는 순서가 보장되지 않는다**

```swift
queries.map { URLQueryItem(name: $0.key, value: $0.value) }
```

`[String: String]`은 순서가 없으므로 **매번 쿼리 순서가 달라질 수 있다.** 대부분의 서버는 순서를 신경 쓰지 않지만, URL 캐싱이나 서명(signature) 기반 API에서는 문제가 된다.

순서가 중요하면 정렬하거나 배열로 받는다.

```swift
components.queryItems = queries
    .sorted { $0.key < $1.key }              // 정렬해 일관성 확보
    .map { URLQueryItem(name: $0.key, value: $0.value) }
```

**③ `resolvingAgainstBaseURL: true`의 의미**

상대 URL을 절대 URL로 해석할지 결정한다. 이 예제는 이미 절대 URL이므로 `true`든 `false`든 결과가 같다. 관례적으로 `true`를 쓴다.

### 정리

```text
왜 self에 설정하지 않나
  → URL에 queryItems가 없다. 쿼리를 수정하는 API 자체가 없다
  → URL은 완성된 주소, URLComponents는 부품 조립기

URL → URLComponents(편집) → URL
  값 타입이므로 새 값을 만드는 것이 자연스럽다
  이 패턴은 Swift에서 매우 일반적이다  ✅

문자열 연결보다 안전하다 — 퍼센트 인코딩을 자동 처리

대안: iOS 16+ url.append(queryItems:)
  옵셔널이 사라져 강제 언래핑을 없앨 수 있다
  단, 이쪽은 "추가"이고 queryItems 대입은 "교체"다

개선: guard로 옵셔널 체인 정리, 딕셔너리 순서 주의
```

## 학습 체크리스트

- [ ] `URL`에 `queryItems` 프로퍼티가 없는 것을 자동완성으로 확인한다.
- [ ] `url.query`가 읽기 전용인 것을 확인한다 (대입 시도).
- [ ] `URLComponents`의 프로퍼티들이 `var`인 것을 확인한다.
- [ ] `components?.url`이 `nil`이 되는 경우를 만들어 본다 (scheme 제거 등).
- [ ] 옵셔널 체인을 `guard`로 풀어 `?`를 없애 본다.
- [ ] `url.append(queryItems:)`로 다시 구현하고 옵셔널이 사라지는 것을 확인한다.
- [ ] `Endpoint.withSymbols.url!`의 강제 언래핑을 없앨 수 있는지 시험한다.
- [ ] 쿼리 값에 공백과 한글을 넣어 퍼센트 인코딩이 되는지 확인한다.
- [ ] 문자열 연결로 같은 URL을 만들어 보고 인코딩 차이를 비교한다.
- [ ] 같은 딕셔너리로 여러 번 호출해 쿼리 순서가 달라지는지 확인한다.
- [ ] `sorted`를 추가해 순서를 고정해 본다.
- [ ] `setQueries`를 `addingQueries`로 이름을 바꿔 API 관례에 맞춰 본다.
- [ ] `queryItems` 대입(교체)과 `append`(추가)의 차이를 실험한다.

## 공식 참고 자료

- [Apple: URLComponents](https://developer.apple.com/documentation/foundation/urlcomponents)
- [Apple: URLComponents.url](https://developer.apple.com/documentation/foundation/urlcomponents/url)
- [Apple: URLComponents.queryItems](https://developer.apple.com/documentation/foundation/urlcomponents/queryitems)
- [Apple: URLComponents.init(url:resolvingAgainstBaseURL:)](https://developer.apple.com/documentation/foundation/urlcomponents/init(url:resolvingagainstbaseurl:))
- [Apple: URLQueryItem](https://developer.apple.com/documentation/foundation/urlqueryitem)
- [Apple: URL](https://developer.apple.com/documentation/foundation/url)
- [Apple: URL.append(queryItems:)](https://developer.apple.com/documentation/foundation/url/append(queryitems:))
- [Apple: URL.appending(queryItems:)](https://developer.apple.com/documentation/foundation/url/appending(queryitems:))
- [Swift API Design Guidelines — Naming](https://www.swift.org/documentation/api-design-guidelines/#naming)
