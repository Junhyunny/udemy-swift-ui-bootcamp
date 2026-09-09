# API 응답 모델에 옵셔널을 써야 하나

`Codable`과 `CodingKeys`는 [별도 문서](./codable-and-codingkey.md)에 정리했다. 이 문서는 **모델 설계에서 옵셔널을 언제 쓸지**를 다룬다.

## 질문이 나온 코드

`chapter-80/chapter-80/Models/ExchangeRate.swift`

```swift
struct ExchangeRate: Codable, Identifiable, Equatable {
    let id = UUID()
    let date: String?
    let rates: [String: Double]?

    private enum CodingKeys: String, CodingKey {
        case date, rates
    }
}
```

## 공부할 내용

### 짐작이 맞다 — 비옵셔널이면 디코딩이 실패한다

**옵셔널 여부가 "이 필드가 없어도 되는가"를 결정한다.**

| 선언 | JSON에 키가 없을 때 | `null`일 때 |
| --- | --- | --- |
| `let date: String` | **디코딩 실패** (`keyNotFound`) | **디코딩 실패** (`valueNotFound`) |
| `let date: String?` | `nil` — 성공 | `nil` — 성공 |

**비옵셔널은 "반드시 있어야 한다"는 계약이다.** 없으면 전체 디코딩이 실패해 모델 하나도 못 만든다.

```swift
// rates가 비옵셔널이면
struct ExchangeRate: Decodable {
    let rates: [String: Double]
}

// API가 오류 응답을 주면
// {"success": false, "error": {...}}
// → rates 키가 없어 디코딩 실패 → 오류 내용도 읽을 수 없다
```

### 하지만 "전부 옵셔널"은 답이 아니다

옵셔널로 도배하면 디코딩은 성공하지만 **문제가 뒤로 밀린다.**

```swift
// 모델은 만들어지지만
let rate = try decoder.decode(ExchangeRate.self, from: data)

// 쓸 때마다 풀어야 한다
guard let rates = rate.rates else { return }
guard let date = rate.date else { return }
```

`ViewModel`이 실제로 그 비용을 치르고 있다.

```swift
func validateOutput() -> [Dictionary<String, Double>.Keys.Element] {
    guard let output = exchangeRate?.rates?.keys.sorted() else {
        return []
    }
    return output
}
```

**옵셔널이 두 겹**이다 (`exchangeRate?`와 `rates?`). 함수 이름이 `validateOutput`인 것도 징후다 — 모델이 이미 유효하다면 "검증"이 필요 없다.

```swift
func formatRateForLocale(for key: String) -> String {
    guard let mainRates = exchangeRate?.rates else { return "" }
    // ...
}
```

여기서도 같은 언래핑을 반복한다. **옵셔널을 미루면 호출부마다 처리 코드가 늘어난다.**

### 기준 — API 계약을 그대로 반영한다

**옵셔널은 "선택"이 아니라 "사실의 반영"이어야 한다.**

```text
질문: 이 필드가 없는 응답이 실제로 오는가?
  예   → 옵셔널
  아니오 → 비옵셔널
```

exchangeratesapi.io를 예로 보면 이렇다.

| 필드 | 성공 시 | 실패 시 | 판단 |
| --- | --- | --- | --- |
| `success` | 있음 | 있음 | **비옵셔널** |
| `base` | 있음 | 없음 | 옵셔널 |
| `date` | 있음 | 없음 | 옵셔널 |
| `rates` | 있음 | 없음 | 옵셔널 |
| `error` | **없음** | 있음 | 옵셔널 |

**성공과 실패 응답이 다른 형태**라서 옵셔널이 필요해진다. 이 예제의 `date`, `rates` 옵셔널은 그 사실을 반영한 것이므로 **타당하다.**

### 더 나은 설계 — 성공과 실패를 타입으로 분리

옵셔널이 생기는 근본 원인이 **"한 타입으로 두 상태를 표현"** 하는 것이다. 나누면 옵셔널이 사라진다.

```swift
/// 서버 응답의 원형 — 디코딩 전용
struct ExchangeRateResponse: Decodable {
    let success: Bool
    let base: String?
    let date: String?
    let rates: [String: Double]?
    let error: APIError?

    struct APIError: Decodable {
        let code: String?
        let info: String?
    }
}

/// 앱이 실제로 쓰는 타입 — 옵셔널이 없다
struct ExchangeRate {
    let base: String
    let date: String
    let rates: [String: Double]
}
```

디코딩 후 변환하면서 검증한다.

```swift
extension ExchangeRateResponse {
    func toDomain() throws -> ExchangeRate {
        guard success else {
            throw ExchangeRateError.api(message: error?.info ?? "알 수 없는 오류")
        }
        guard let base, let date, let rates else {
            throw ExchangeRateError.incompleteResponse
        }
        return ExchangeRate(base: base, date: date, rates: rates)
    }
}
```

**이 방식의 이점**

- **옵셔널 처리가 한 곳에 모인다.** 호출부는 옵셔널을 모른다
- 뷰와 뷰모델 코드가 단순해진다 — `validateOutput()` 같은 함수가 불필요
- 실패 원인을 [구체적인 오류로](./async-throws-and-custom-errors.md) 표현할 수 있다
- API 응답 형태가 바뀌어도 도메인 타입은 영향받지 않는다

**비용**은 타입 두 개와 변환 코드다. 작은 프로젝트에서는 과할 수 있다.

### 절충 — 기본값을 주는 방법

타입을 나누지 않고 옵셔널을 없애는 방법도 있다.

```swift
struct ExchangeRate: Decodable {
    let date: String
    let rates: [String: Double]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decodeIfPresent(String.self, forKey: .date) ?? ""
        rates = try container.decodeIfPresent([String: Double].self, forKey: .rates) ?? [:]
    }
}
```

`decodeIfPresent`로 읽고 `??`로 기본값을 준다. **모델은 비옵셔널이 되어 호출부가 깔끔해진다.**

**단점**은 "없음"과 "빈 값"을 구분할 수 없다는 것이다. 환율이 실제로 빈 딕셔너리인 경우와 응답이 실패한 경우가 같아진다. 이 예제에서는 실패를 구분해야 하므로 부적합하다.

### 판단 기준 정리

```text
① 이 필드가 없는 응답이 실제로 오는가?
     아니오 → 비옵셔널 (계약을 명시)
     예 → ②

② 없음과 빈 값을 구분해야 하는가?
     예 → 옵셔널 유지
     아니오 → decodeIfPresent + 기본값

③ 성공/실패 응답 형태가 다른가?
     예 → 응답 타입과 도메인 타입 분리   ← 이 예제에 적합
     아니오 → 옵셔널로 충분
```

### 이 예제에서 확인할 것

**① 옵셔널 자체는 타당하다**

API가 실패 시 `rates`를 안 주므로 옵셔널이 맞다. 무조건 비옵셔널로 바꾸면 오류 응답을 받을 수 없다.

**② `success`와 `error`가 빠져 있다**

```swift
private enum CodingKeys: String, CodingKey {
    case date, rates      // success, error가 없다
}
```

exchangeratesapi.io는 **실패해도 HTTP 200을 주고 본문에 `success: false`를 담는다.** 지금 모델은 이것을 읽지 않으므로 **오류를 감지할 방법이 없다.** 잘못된 API 키를 써도 `rates`가 `nil`인 빈 모델이 되고, 사용자는 이유를 알 수 없다.

`success`와 `error`를 추가하면 원인을 파악할 수 있다.

**③ `let id = UUID()`가 매번 새 값이다**

```swift
let id = UUID()
```

[Hashable과 신원 문제](./hashable-id-and-collisions.md)에서 다룬 함정이다. `Equatable`을 채택했지만 `id`가 `CodingKeys`에 없어 디코딩마다 새 UUID가 생긴다. 같은 응답을 두 번 받으면 `==`가 `false`다.

`ExchangeRate`는 목록에 나열되는 타입이 아니므로 `Identifiable`이 필요한지부터 검토할 만하다. 필요하면 의미 있는 값을 쓴다.

```swift
var id: String { date ?? "unknown" }
```

**④ `placeholder`가 오류를 감춘다**

```swift
static var placeholder: ExchangeRate {
    Self(date: nil, rates: nil)
}
```

[`replaceError(with:)`](./combine-operators.md)와 결합해 **모든 실패가 빈 데이터로 뭉개진다.** 옵셔널 설계와 오류 처리가 함께 문제를 만드는 사례다.

### 정리

```text
비옵셔널 → 없으면 디코딩 실패  ✅ 짐작이 맞다
옵셔널   → 없어도 성공

하지만 "전부 옵셔널"은 문제를 뒤로 미루는 것이다
  호출부마다 언래핑 → validateOutput() 같은 함수가 생긴다

기준: 옵셔널은 "선택"이 아니라 "API 사실의 반영"
  없는 응답이 실제로 오는가? → 예면 옵셔널

이 예제는 성공/실패 응답 형태가 달라 옵셔널이 타당하다
  다만 success, error를 읽지 않아 오류를 감지하지 못한다

더 나은 설계: 응답 타입과 도메인 타입 분리
  옵셔널 처리를 한 곳에 모으고 호출부를 깔끔하게
```

## 학습 체크리스트

- [ ] `rates`를 비옵셔널로 바꾸고 오류 응답을 받아 디코딩이 실패하는 것을 확인한다.
- [ ] 잘못된 API 키로 요청해 실제 응답 JSON을 출력한다.
- [ ] `success`와 `error` 필드를 모델에 추가해 오류 메시지를 읽어 본다.
- [ ] `CodingKeys`에 `success`, `error`를 추가하지 않으면 읽히지 않는 것을 확인한다.
- [ ] `DecodingError`를 `switch`로 분기해 `keyNotFound`와 `valueNotFound`를 구분한다.
- [ ] `decodeIfPresent` + `??`로 기본값을 주는 방식을 구현해 본다.
- [ ] 응답 타입과 도메인 타입을 분리하고 `toDomain()` 변환을 만들어 본다.
- [ ] 분리 후 `validateOutput()`이 불필요해지는지 확인한다.
- [ ] `ExchangeRate` 두 개를 디코딩해 `==`가 `false`인 것을 확인한다 (`id` 문제).
- [ ] `Identifiable`이 실제로 필요한지 검토하고, 필요하면 `date` 기반 `id`로 바꿔 본다.
- [ ] `placeholder`와 `replaceError`가 함께 오류를 감추는 흐름을 추적한다.

## 공식 참고 자료

- [Apple: Decodable](https://developer.apple.com/documentation/swift/decodable)
- [Apple: Codable](https://developer.apple.com/documentation/swift/codable)
- [Apple: CodingKey](https://developer.apple.com/documentation/swift/codingkey)
- [Apple: KeyedDecodingContainer.decodeIfPresent(_:forKey:)](https://developer.apple.com/documentation/swift/keyeddecodingcontainer/decodeifpresent(_:forkey:)-1ycfp)
- [Apple: KeyedDecodingContainer.decode(_:forKey:)](https://developer.apple.com/documentation/swift/keyeddecodingcontainer/decode(_:forkey:)-6ivmr)
- [Apple: DecodingError](https://developer.apple.com/documentation/swift/decodingerror)
- [Apple: JSONDecoder](https://developer.apple.com/documentation/foundation/jsondecoder)
- [Swift 공식 문서: The Basics — Optionals](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/#Optionals)
- [Swift 공식 문서: Initialization — Failable Initializers](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/initialization/#Failable-Initializers)
