# URL 탐지의 원리와 `NSDataDetector`의 `matches` API

## 질문이 나온 코드

`chapter-50/chapter-50/ContentView.swift`

```swift
func extractFirstURL(from text: String) -> URL? {
    let types: NSTextCheckingResult.CheckingType = .link
    guard let detector = try? NSDataDetector(types: types.rawValue) else {
        return nil
    }
    let matches = detector.matches(
        in: text,
        options: [],
        range: NSRange(location: 0, length: text.utf16.count)
    )
    return matches.first?.url
}
```

두 가지가 궁금하다. **URL을 찾아내는 원리가 정규식인가?** 그리고 **`matches`의 각 파라미터는 무슨 역할인가?**

## 공부할 내용

## 1부 — 탐지 원리: 정규식인가?

### 절반은 맞다 — 상속 구조가 그렇다

`NSDataDetector`는 **`NSRegularExpression`의 서브클래스**다. 그래서 `matches(in:options:range:)`, `numberOfMatches(in:options:range:)`, `firstMatch(in:options:range:)`, `enumerateMatches(in:options:range:usingBlock:)` 같은 메서드를 그대로 물려받는다.

예제가 호출하는 `matches`도 원래 `NSRegularExpression`의 메서드다.

> After creating the data detector instance, you can determine the number of matches within a range of a string using the `NSRegularExpression` method `numberOfMatches(in:options:range:)`.

### 하지만 동작 방식은 정규식이 아니다

중요한 차이가 있다. **패턴 문자열을 받지 않는다.**

```swift
// NSRegularExpression — 패턴을 내가 준다
let regex = try NSRegularExpression(pattern: "https?://[a-zA-Z0-9./]+")

// NSDataDetector — 무엇을 찾을지 "종류"만 지정한다
let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
```

Apple의 설명이 성격을 말해 준다.

> Find dates, addresses, links, phone numbers, and transit information in **natural language text** with `NSDataDetector`.

**자연어 텍스트**가 핵심이다. 내부적으로는 단순 패턴 매칭이 아니라 시스템의 데이터 탐지 엔진이 동작한다. 실제로 정규식만으로는 처리하기 어려운 것들을 잡아낸다.

- `www.google.com` — 스킴이 없어도 링크로 인식하고 `https://`를 붙여 준다
- 문장 끝의 마침표를 URL에서 제외한다 (`Visit google.com.` → `google.com`)
- 주소·날짜·전화번호는 지역과 형식이 제각각이라 정규식으로 감당이 안 된다

반환값도 다르다.

> `NSDataDetector` returns the results of matching content in `NSTextCheckingResult` objects. The `NSTextCheckingResult` objects that `NSDataDetector` returns are different from those that `NSRegularExpression` returns. The results are one of the data detector's types and contain the corresponding properties. For example, results of type `date` have a `date`, `timeZone`, and `duration`; and results of type `link` have a `url`.

정규식 결과는 "몇 번째 글자부터 몇 글자"라는 범위 정보뿐이지만, 데이터 탐지 결과는 **의미가 파싱된 값**을 들고 온다. 예제가 `matches.first?.url`로 곧바로 `URL` 객체를 꺼낼 수 있는 이유가 이것이다. 문자열을 잘라내서 다시 `URL(string:)`으로 변환할 필요가 없다.

정리하면 이렇다.

| | `NSRegularExpression` | `NSDataDetector` |
| --- | --- | --- |
| 무엇을 주나 | 패턴 문자열 | 찾을 **종류** |
| 대상 | 임의의 텍스트 | **자연어 텍스트** |
| 결과 | 매칭 범위 | 범위 + **파싱된 값** (`url`, `date`, `phoneNumber`) |
| 관계 | 부모 클래스 | 자식 클래스 |

### 찾을 수 있는 종류

`NSDataDetector`가 지원하는 것은 다섯 가지다.

> Currently, the supported data detectors `checkingTypes` are: `NSTextCheckingTypeDate`, `NSTextCheckingTypeAddress`, `NSTextCheckingTypeLink`, `NSTextCheckingTypePhoneNumber`, and `NSTextCheckingTypeTransitInformation`.

| 타입 | 찾는 것 | 결과에서 꺼낼 값 |
| --- | --- | --- |
| `.link` | URL, 이메일 | `url` |
| `.date` | 날짜·시간 표현 | `date`, `timeZone`, `duration` |
| `.address` | 주소 | `addressComponents` |
| `.phoneNumber` | 전화번호 | `phoneNumber` |
| `.transitInformation` | 항공편 등 | `components` |

`NSTextCheckingResult.CheckingType`에는 `.spelling`, `.grammar`, `.quote` 같은 값도 있지만, 그건 맞춤법 검사기(`NSSpellChecker`)용이라 데이터 탐지기에는 쓸 수 없다.

여러 종류를 한 번에 찾으려면 비트 OR로 묶는다.

```swift
let types: NSTextCheckingResult.CheckingType = [.link, .phoneNumber, .date]
let detector = try? NSDataDetector(types: types.rawValue)
```

`rawValue`를 넘기는 이유는 이니셜라이저가 `NSTextCheckingTypes`(= `UInt64`)를 받기 때문이다. Objective-C의 비트 플래그를 그대로 물려받은 시그니처다.

```swift
init(types checkingTypes: NSTextCheckingTypes) throws
```

### 중요한 경고 — 검증에 쓰지 말 것

Apple이 명시적으로 경고한다.

> **Important:** Don't use `NSDataDetector` to validate data. `NSDataDetector` discards potential matches in case of uncertainty. Use a class specific to the type of data for validation instead. For example, attempt to instantiate a `URL` object using `init(string:)` to validate a URL string. A valid URL string returns an instance of `URL`, while an invalid URL string returns `nil`.

**탐지기는 "찾기"용이지 "검사"용이 아니다.** 애매하면 그냥 버린다. 사용자가 입력한 문자열이 올바른 URL인지 확인하려면 `URL(string:)`을 쓴다.

chapter-49의 예제가 정확히 그 검증 상황이었다는 점과 대비된다.

또 하나의 제약도 있다.

> **Note:** Only use `NSDataDetector` on natural language text.
>
> If you expect text to be in a particular format, use an `NSFormatter` or `NSRegularExpression` subclass instead. (…) If the text is in a machine-readable format, such as XML or JSON, extract the natural language text (…) and match on that rather than attempt to match on the entire document.

JSON이나 XML 전체를 넣지 말라는 뜻이다. 예제의 `TextEditor` 입력은 자연어이므로 적절한 사용이다.

## 2부 — `matches` API 상세

### 시그니처

```swift
func matches(
    in string: String,
    options: NSRegularExpression.MatchingOptions = [],
    range: NSRange
) -> [NSTextCheckingResult]
```

`NSRegularExpression`에서 물려받은 메서드다.

> The `matches(in:options:range:)` method is similar to `firstMatch(in:options:range:)`, except that it returns all matches rather than only the first.

### 파라미터 ① `in:` — 검사할 문자열

전체 원본 문자열을 넘긴다. **자르지 않고 통째로** 준다. 어느 부분을 볼지는 세 번째 `range:`가 정한다.

### 파라미터 ② `options:` — 매칭 동작 조절

`NSRegularExpression.MatchingOptions`이고, 예제는 `[]`(빈 집합, 기본값)을 준다. 대부분의 경우 이걸로 충분하다.

사용 가능한 옵션은 다섯 가지다.

| 옵션 | 의미 |
| --- | --- |
| `.reportProgress` | 진행 상황을 중간중간 콜백 (enumerate 계열에서만 의미) |
| `.reportCompletion` | 완료 시점을 콜백 |
| `.anchored` | `range`의 **시작 위치에서만** 매칭 시도 |
| `.withTransparentBounds` | 경계 밖 문자도 lookahead/lookbehind에 참여시킴 |
| `.withoutAnchoringBounds` | `^`, `$`가 range 경계에 매칭되지 않게 함 |

앞의 두 개는 `enumerateMatches(in:options:range:usingBlock:)`에서만 실질적 의미가 있다. 뒤의 세 개는 정규식 문맥에서 쓰이는 것이라 데이터 탐지기에서는 거의 쓸 일이 없다.

기본값이 `[]`이므로 아예 생략할 수도 있다.

```swift
let matches = detector.matches(
    in: text,
    range: NSRange(location: 0, length: text.utf16.count)
)
```

### 파라미터 ③ `range:` — 검사 범위

여기가 가장 주의할 부분이다.

```swift
NSRange(location: 0, length: text.utf16.count)
```

`NSRange`는 **시작 위치와 길이**로 표현되는 구조체이고, `location: 0, length: 전체길이`는 "문자열 전체"를 뜻한다.

**왜 `text.count`가 아니라 `text.utf16.count`인가?** 이게 이 코드의 숨은 핵심이다.

`NSRange`는 Objective-C의 `NSString`을 전제로 하고, `NSString`은 **UTF-16 코드 유닛** 단위로 길이를 센다. 반면 Swift의 `String.count`는 사람이 인식하는 **문자(Character, grapheme cluster)** 단위다. 둘은 자주 다르다.

```swift
let s = "안녕👋"
s.count            // 3  — 사람 기준 문자 수
s.utf16.count      // 4  — 👋가 UTF-16에서 2개 유닛(surrogate pair)
```

| 문자열 | `count` | `utf16.count` |
| --- | --- | --- |
| `"hello"` | 5 | 5 |
| `"안녕하세요"` | 5 | 5 |
| `"👋"` | 1 | **2** |
| `"👨‍👩‍👧‍👦"` | 1 | **11** |
| `"e\u{301}"` (é) | 1 | 2 |

`text.count`를 쓰면 이모지가 포함된 순간 범위가 실제보다 짧아져 **뒷부분을 검사하지 못하거나 크래시**할 수 있다. `utf16.count`가 정답이다.

이 불일치는 [Swift의 기본 타입과 비교 방법](./swift-fundamental-types-and-comparison.md)에서 다룬 `String`의 문자 모델과 이어지고, `NS` 접두사 API를 Swift에서 쓸 때 반복해서 만나는 문제다. 배경은 [NS 접두사 문서](./ns-prefix-foundation-classes.md)에 정리했다.

전체 범위라면 더 안전한 표현도 있다.

```swift
let range = NSRange(text.startIndex..., in: text)
```

`String.Index` 범위를 `NSRange`로 정확히 변환해 주므로 계산 실수가 없다. 부분 범위를 다룰 때 특히 유용하다.

### 반환값 — `[NSTextCheckingResult]`

찾은 결과가 배열로 온다. 하나도 없으면 빈 배열이다. `nil`이 아니다.

각 결과에서 꺼낼 수 있는 것들이다.

| 프로퍼티 | 의미 |
| --- | --- |
| `range` | 매칭된 범위 (`NSRange`) |
| `resultType` | 어떤 종류로 잡혔는지 |
| `url` | `.link`일 때의 URL |
| `date`, `timeZone`, `duration` | `.date`일 때 |
| `phoneNumber` | `.phoneNumber`일 때 |
| `addressComponents` | `.address`일 때 |

예제는 첫 번째 결과의 `url`만 쓴다.

```swift
return matches.first?.url
```

`first`는 `Optional`이고 `url`도 `Optional`이라 옵셔널 체이닝으로 이어진다. 결과가 없으면 자연스럽게 `nil`이 된다.

### 여러 종류를 함께 다루기

Apple 문서의 Objective-C 예제를 Swift로 옮기면 이런 형태다.

```swift
let types: NSTextCheckingResult.CheckingType = [.link, .phoneNumber]
guard let detector = try? NSDataDetector(types: types.rawValue) else { return }

let matches = detector.matches(
    in: text,
    range: NSRange(text.startIndex..., in: text)
)

for match in matches {
    switch match.resultType {
    case .link:
        print("URL:", match.url as Any)
    case .phoneNumber:
        print("전화:", match.phoneNumber as Any)
    default:
        break
    }
}
```

`resultType`으로 분기하는 것이 핵심이다. 한 detector가 여러 종류를 동시에 찾을 수 있기 때문이다.

### 형제 메서드들

용도에 따라 더 나은 선택지가 있다.

| 메서드 | 반환 | 언제 |
| --- | --- | --- |
| `matches(in:options:range:)` | `[NSTextCheckingResult]` | 전부 필요할 때 |
| `firstMatch(in:options:range:)` | `NSTextCheckingResult?` | **첫 개만 필요할 때** |
| `numberOfMatches(in:options:range:)` | `Int` | 개수만 필요할 때 |
| `rangeOfFirstMatch(in:options:range:)` | `NSRange` | 위치만 필요할 때 |
| `enumerateMatches(in:options:range:using:)` | — | 중간에 멈춰야 할 때 |

**예제는 `matches.first`를 쓰므로 `firstMatch`가 더 적절하다.** 전부 찾아 배열을 만든 뒤 첫 개만 쓰는 것은 낭비다.

```swift
func extractFirstURL(from text: String) -> URL? {
    let types: NSTextCheckingResult.CheckingType = .link
    guard let detector = try? NSDataDetector(types: types.rawValue) else {
        return nil
    }
    return detector.firstMatch(
        in: text,
        range: NSRange(text.startIndex..., in: text)
    )?.url
}
```

중간에 멈춰야 한다면 `enumerateMatches`를 쓴다. Apple 문서의 설명이 그 용도를 말한다.

> The `NSRegularExpression` block object enumerator is the most general and flexible of the matching methods. It allows you to iterate through matches in a string, performing arbitrary actions on each as specified by the code in the block, and to stop partway through if desired.

### 성능 — 이 예제의 개선 여지

`extractFirstURL`은 [`onChange`](./onchange-old-new-value.md)를 통해 **타이핑할 때마다** 호출된다. 두 가지 비용이 매번 발생한다.

- `NSDataDetector` 인스턴스를 새로 생성한다. 생성 비용이 싸지 않다.
- 텍스트 전체를 다시 훑는다.

detector를 재사용하면 첫 번째 비용이 사라진다.

```swift
struct ContentView: View {
    private static let linkDetector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
    )

    func extractFirstURL(from text: String) -> URL? {
        Self.linkDetector?.firstMatch(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        )?.url
    }
}
```

`static`이라 타입당 하나만 만들어진다. 긴 글에서 입력이 버벅인다면 여기에 디바운스를 더한다.

## 학습 체크리스트

- [ ] `www.google.com`처럼 스킴 없는 문자열을 입력해 URL로 인식되는지 확인한다.
- [ ] `Visit google.com.`처럼 마침표로 끝나는 문장을 넣어 URL에서 마침표가 빠지는지 본다.
- [ ] `types`에 `.phoneNumber`, `.date`를 추가하고 `resultType`으로 분기해 본다.
- [ ] 여러 URL이 든 텍스트를 넣고 `matches`가 몇 개를 돌려주는지 센다.
- [ ] `matches` 대신 `firstMatch`로 바꿔 같은 결과가 나오는지 확인한다.
- [ ] `text.utf16.count`를 `text.count`로 바꾸고 이모지를 입력해 문제를 재현한다.
- [ ] `"안녕👋"`의 `count`와 `utf16.count`를 출력해 차이를 확인한다.
- [ ] `NSRange(text.startIndex..., in: text)`로 바꿔 동작이 같은지 확인한다.
- [ ] `options`에 `.anchored`를 넣고 결과가 어떻게 달라지는지 본다.
- [ ] `options` 인자를 아예 생략해도 컴파일되는지 확인한다 (기본값 `[]`).
- [ ] `match.range`로 원문에서 URL 위치를 찾아 하이라이트해 본다.
- [ ] 같은 문자열을 `NSRegularExpression`으로 직접 패턴을 짜서 찾아 보고 난이도를 비교한다.
- [ ] `URL(string: "httpsgoogle.com")`이 무엇을 돌려주는지 확인하고, 탐지와 검증의 차이를 설명한다.
- [ ] detector를 `static`으로 빼고 타이핑 반응 속도가 달라지는지 체감한다.

## 공식 참고 자료

- [Apple: NSDataDetector](https://developer.apple.com/documentation/foundation/nsdatadetector)
- [Apple: NSDataDetector.init(types:)](https://developer.apple.com/documentation/foundation/nsdatadetector/init(types:))
- [Apple: NSDataDetector.checkingTypes](https://developer.apple.com/documentation/foundation/nsdatadetector/checkingtypes)
- [Apple: NSRegularExpression.matches(in:options:range:)](https://developer.apple.com/documentation/foundation/nsregularexpression/matches(in:options:range:))
- [Apple: NSRegularExpression.MatchingOptions](https://developer.apple.com/documentation/foundation/nsregularexpression/matchingoptions)
- [Apple: NSRegularExpression](https://developer.apple.com/documentation/foundation/nsregularexpression)
- [Apple: NSTextCheckingResult](https://developer.apple.com/documentation/foundation/nstextcheckingresult)
- [Apple: NSTextCheckingResult.CheckingType](https://developer.apple.com/documentation/foundation/nstextcheckingresult/checkingtype)
- [Apple: NSRange](https://developer.apple.com/documentation/foundation/nsrange)
- [Apple: URL](https://developer.apple.com/documentation/foundation/url)
- [Swift 공식 문서: Strings and Characters — Unicode](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/#Unicode)
