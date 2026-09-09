# 통화 코드로 국기 이모지 만들기 — `compactMap`과 유니코드

## 질문이 나온 코드

`chapter-80/chapter-80/ViewModels/ViewModel.swift`

```swift
func emojiFlag(_ currencyCode: String) -> String {
    guard let country = Country.getCountryBy(currencyCode: currencyCode) else {
        return currencyCode
            .dropLast()
            .unicodeScalars
            .map({ 127397 + $0.value })
            .compactMap(UnicodeScalar.init)
            .map(String.init)
            .joined()
    }
    return country.flagEmoji
}
```

## 공부할 내용

### 무엇을 하는 코드인가

**통화 코드에서 국가 코드를 뽑아 국기 이모지를 계산한다.** `Country.sample`에 없는 통화가 들어와도 국기를 표시하기 위한 fallback이다.

```text
"KRW"  →  dropLast()  →  "KR"  →  🇰🇷
"AUD"  →  dropLast()  →  "AU"  →  🇦🇺
```

### 핵심 원리 — 국기 이모지는 두 글자의 조합이다

이 코드를 이해하는 열쇠다. **국기 이모지는 하나의 문자가 아니다.**

유니코드에는 **Regional Indicator Symbol**이라는 문자 26개(A~Z)가 있다. 두 개를 나란히 놓으면 시스템이 국기로 렌더링한다.

```text
🇰 (Regional Indicator K) + 🇷 (Regional Indicator R)  →  🇰🇷
```

각각을 따로 보면 그냥 네모난 글자이고, 붙여야 국기가 된다.

**Regional Indicator의 코드 포인트**는 이렇다.

| 문자 | 유니코드 | 10진수 |
| --- | --- | --- |
| `A` (ASCII) | U+0041 | **65** |
| 🇦 (Regional Indicator A) | U+1F1E6 | **127462** |

차이가 `127462 - 65 = 127397`이다. **코드의 마법 숫자 127397이 여기서 나온다.**

```swift
.map({ 127397 + $0.value })
//      ↑ ASCII 대문자 → Regional Indicator 변환 오프셋
```

### 한 단계씩 따라가기

`"KRW"`를 넣었다고 하자.

**① `.dropLast()` — 통화 코드에서 국가 코드로**

```swift
"KRW".dropLast()    // "KR"
```

ISO 4217 통화 코드는 대체로 **`ISO 3166 국가 코드(2자) + 통화 이니셜(1자)`** 형태다.

```text
KR + W = KRW  (Korea Won)
JP + Y = JPY  (Japan Yen)
US + D = USD  (US Dollar)
AU + D = AUD  (Australia Dollar)
```

마지막 한 글자를 떼면 국가 코드가 된다.

반환 타입이 `String`이 아니라 `Substring`이지만, 이후 연산에는 문제가 없다.

**② `.unicodeScalars` — 문자를 코드 포인트로**

```swift
"KR".unicodeScalars    // [U+004B, U+0052]  → 값은 [75, 82]
```

`String`을 유니코드 스칼라(코드 포인트) 단위로 본다. `K`는 75, `R`은 82다.

[NS 접두사 문서](./ns-prefix-foundation-classes.md)에서 다룬 `utf16` 같은 다른 뷰도 있는데, 여기서는 코드 포인트 단위인 `unicodeScalars`가 맞다.

**③ `.map({ 127397 + $0.value })` — 오프셋을 더한다**

```swift
[75, 82]  →  [127472, 127479]
//            75+127397, 82+127397
```

`$0.value`는 `UInt32`다. 결과는 Regional Indicator K와 R의 코드 포인트다.

**④ `.compactMap(UnicodeScalar.init)` — 숫자를 문자로**

**질문의 핵심인 `compactMap`이 여기 있다.**

```swift
UnicodeScalar.init(_ v: UInt32) -> UnicodeScalar?    // 실패 가능 → 옵셔널
```

`UnicodeScalar`의 이니셜라이저는 **실패 가능하다.** 모든 `UInt32` 값이 유효한 유니코드 스칼라는 아니기 때문이다 (서로게이트 영역 등은 무효다).

그래서 `map`을 쓰면 `[UnicodeScalar?]`가 되고, `compactMap`을 쓰면 **`nil`을 걸러내고 `[UnicodeScalar]`가 된다.**

```swift
// map을 쓰면
.map(UnicodeScalar.init)         // [UnicodeScalar?] — 옵셔널 배열

// compactMap을 쓰면
.compactMap(UnicodeScalar.init)  // [UnicodeScalar] — nil 제거됨
```

**이것이 `compactMap`의 정체다. "변환하고 `nil`을 버린다."**

```swift
["1", "x", "3"].map { Int($0) }         // [Optional(1), nil, Optional(3)]
["1", "x", "3"].compactMap { Int($0) }  // [1, 3]
```

[클로저 축약 문서](./closure-shorthand-argument-names.md)에서 예로 든 것과 같은 연산자다.

**`UnicodeScalar.init`을 그냥 넘기는 것**도 눈여겨볼 만하다. 클로저 대신 이니셜라이저를 함수 값으로 전달하는 방식이다. `{ UnicodeScalar($0) }`와 같다.

**⑤ `.map(String.init)` — 각각을 문자열로**

```swift
[🇰, 🇷]  →  ["🇰", "🇷"]
```

`String(UnicodeScalar)` 이니셜라이저를 함수로 넘긴 것이다.

**⑥ `.joined()` — 합친다**

```swift
["🇰", "🇷"]  →  "🇰🇷"
```

두 Regional Indicator가 붙으면서 시스템이 국기로 렌더링한다.

### 전체 흐름

```text
"KRW"
  ↓ dropLast()
"KR"
  ↓ unicodeScalars
[75, 82]                        (K, R의 ASCII)
  ↓ map { 127397 + $0.value }
[127472, 127479]                (Regional Indicator K, R)
  ↓ compactMap(UnicodeScalar.init)
[🇰, 🇷]                          (유효하지 않은 값은 버림)
  ↓ map(String.init)
["🇰", "🇷"]
  ↓ joined()
"🇰🇷"
```

### 더 읽기 쉽게 쓰는 방법

동작은 정확하지만 체인이 길어 의도가 잘 안 보인다. 몇 가지 대안이 있다.

**① 단계에 이름을 붙인다**

```swift
func emojiFlag(_ currencyCode: String) -> String {
    if let country = Country.getCountryBy(currencyCode: currencyCode) {
        return country.flagEmoji
    }

    // 통화 코드 앞 2자리가 ISO 국가 코드인 관례를 이용한다.
    let countryCode = currencyCode.dropLast().uppercased()
    return Self.flagEmoji(fromCountryCode: countryCode)
}

/// 국가 코드(예: "KR")를 국기 이모지로 바꾼다.
///
/// 국기 이모지는 Regional Indicator Symbol 두 개의 조합이다.
/// ASCII 대문자에 127397을 더하면 대응하는 Regional Indicator가 된다.
private static func flagEmoji(fromCountryCode code: String) -> String {
    let regionalIndicatorOffset: UInt32 = 127397

    return code.unicodeScalars
        .compactMap { UnicodeScalar(regionalIndicatorOffset + $0.value) }
        .map(String.init)
        .joined()
}
```

**② `Locale`을 쓴다 — 더 정확하다**

통화 코드에서 국가를 찾는 더 신뢰할 수 있는 방법이 있다.

```swift
func countryCode(forCurrency currencyCode: String) -> String? {
    Locale.Region.isoRegions
        .first { region in
            Locale(identifier: "en_\(region.identifier)")
                .currency?.identifier == currencyCode
        }?
        .identifier
}
```

느리지만 정확하다. 미리 계산해 딕셔너리로 캐싱하면 실용적이다.

### 이 방식의 한계

**`dropLast()` 관례가 항상 맞지는 않는다.**

| 통화 코드 | 앞 2자리 | 실제 국가 | 결과 |
| --- | --- | --- | --- |
| `KRW` | KR | 한국 | ✅ 🇰🇷 |
| `USD` | US | 미국 | ✅ 🇺🇸 |
| **`EUR`** | **EU** | 유럽연합 | 🇪🇺 (국가는 아니지만 이모지 존재) |
| **`XAU`** | XA | 금(golds) | ❌ 무효 |
| **`XDR`** | XD | IMF 특별인출권 | ❌ 무효 |
| **`CHF`** | CH | 스위스 | ✅ 🇨🇭 (우연히 맞음) |

`X`로 시작하는 코드는 국가가 아닌 통화(귀금속, 국제 단위)라 이 방식이 통하지 않는다. 무효한 조합은 국기 대신 **네모난 글자 두 개**로 표시된다.

`compactMap`이 `nil`을 걸러 주므로 **크래시는 나지 않는다.** 다만 결과가 국기가 아닐 수 있다. 실제 앱이라면 fallback을 하나 더 두는 것이 안전하다.

```swift
let flag = Self.flagEmoji(fromCountryCode: countryCode)
return flag.isEmpty ? "🏳️" : flag
```

### `map` vs `compactMap` vs `flatMap`

혼동하기 쉬운 세 연산자를 정리하면 이렇다.

| 연산자 | 동작 | 예 |
| --- | --- | --- |
| `map` | 변환 | `[1,2].map { $0 * 2 }` → `[2,4]` |
| `compactMap` | 변환 + **`nil` 제거** | `["1","x"].compactMap(Int.init)` → `[1]` |
| `flatMap` | 변환 + **평탄화** | `[[1],[2]].flatMap { $0 }` → `[1,2]` |

## 학습 체크리스트

- [ ] `"KRW"`를 넣어 🇰🇷이 나오는지 확인한다.
- [ ] 각 단계 결과를 `print`로 찍어 변환 과정을 확인한다.
- [ ] `"KR".unicodeScalars.map(\.value)`를 출력해 `[75, 82]`를 확인한다.
- [ ] `127397 + 75`가 Regional Indicator K의 코드 포인트인지 확인한다.
- [ ] `String(UnicodeScalar(127462)!)`를 출력해 🇦 하나만 보이는 것을 확인한다.
- [ ] 두 개를 붙여 `"🇰" + "🇷"`이 🇰🇷로 렌더링되는 것을 확인한다.
- [ ] `compactMap`을 `map`으로 바꿔 컴파일 에러나 옵셔널 배열이 되는 것을 확인한다.
- [ ] `"XAU"`를 넣어 국기가 아닌 결과가 나오는 것을 확인한다.
- [ ] `"EUR"`를 넣어 🇪🇺가 나오는지 확인한다.
- [ ] 체인을 별도 함수로 분리하고 상수에 이름을 붙여 본다.
- [ ] 빈 결과일 때 🏳️로 fallback하는 코드를 추가한다.
- [ ] `map`, `compactMap`, `flatMap`의 차이를 각각 예제로 확인한다.
- [ ] `UnicodeScalar.init`을 `{ UnicodeScalar($0) }`로 바꿔도 같은지 확인한다.

## 공식 참고 자료

- [Apple: Unicode.Scalar](https://developer.apple.com/documentation/swift/unicode/scalar)
- [Apple: Unicode.Scalar.init(_:)](https://developer.apple.com/documentation/swift/unicode/scalar/init(_:)-6kfxj)
- [Apple: String.unicodeScalars](https://developer.apple.com/documentation/swift/string/unicodescalars-swift.property)
- [Apple: Sequence.compactMap(_:)](https://developer.apple.com/documentation/swift/sequence/compactmap(_:))
- [Apple: Sequence.map(_:)](https://developer.apple.com/documentation/swift/sequence/map(_:))
- [Apple: Sequence.flatMap(_:)](https://developer.apple.com/documentation/swift/sequence/flatmap(_:)-jo0v)
- [Apple: Collection.dropLast(_:)](https://developer.apple.com/documentation/swift/collection/droplast(_:))
- [Apple: Sequence.joined(separator:)](https://developer.apple.com/documentation/swift/sequence/joined(separator:)-7pzmj)
- [Apple: Locale](https://developer.apple.com/documentation/foundation/locale)
- [Swift 공식 문서: Strings and Characters — Unicode](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/#Unicode)
- [Unicode: Regional Indicator Symbols (Enclosed Alphanumeric Supplement)](https://www.unicode.org/charts/PDF/U1F100.pdf)
