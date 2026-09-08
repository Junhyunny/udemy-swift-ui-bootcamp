# `NS` 접두사가 붙은 타입들 — 무엇이고, 왜 아직 남아 있는가

`CG` 접두사는 [Core Graphics 타입 문서](./coregraphics-types-and-cgfloat.md)에서 다뤘다. 이 문서는 `NS` 하나에 집중한다.

## 질문이 나온 코드

`chapter-50/chapter-50/ContentView.swift`

```swift
let types: NSTextCheckingResult.CheckingType = .link
guard let detector = try? NSDataDetector(types: types.rawValue) else {
    return nil
}
let matches = detector.matches(
    in: text,
    options: [],
    range: NSRange(location: 0, length: text.utf16.count)
)
```

한 함수에 `NS`가 셋이나 나온다. 반면 같은 파일의 `URL`, `String`에는 없다. 기준이 무엇인가?

## 공부할 내용

### `NS`는 NeXTSTEP의 약자다

역사적 유래다. Swift 이전, Objective-C 시절 Foundation과 AppKit은 NeXT사의 NeXTSTEP 운영체제에서 왔다. Apple이 NeXT를 인수하면서 그 프레임워크가 macOS의 기반이 됐고, 접두사가 그대로 남았다.

**왜 접두사를 붙였나?** Objective-C에는 **네임스페이스가 없었기 때문이다.** 모든 클래스 이름이 전역이라 충돌을 피하려면 이름 자체에 소속을 새겨야 했다. `CG`, `CF`, `CA`, `UI` 같은 접두사가 전부 같은 이유로 생겼다.

Swift는 모듈 단위 네임스페이스가 있어 이 관행이 필요 없다. 그래서 SwiftUI의 타입은 `SUView`가 아니라 그냥 `View`다.

### 그래서 Swift 3에서 대거 걷어냈다 — SE-0086

Swift Evolution 제안 SE-0086 "Drop NS Prefix in Swift Foundation"이 이 정리를 수행했다.

동기는 이렇다.

> The type names should be clear, concise, and omit needless words or prefixes.

80개가 넘는 타입이 접두사를 잃었다.

| 이전 | 현재 |
| --- | --- |
| `NSBundle` | `Bundle` |
| `NSFileManager` | `FileManager` |
| `NSURLSession` | `URLSession` |
| `NSTimer` | `Timer` |
| `NSOperation` | `Operation` |
| `NSTask` | `Process` |
| `NSNotificationCenter` | `NotificationCenter` |
| `NSUserDefaults` | `UserDefaults` |

이것이 예제 코드에서 `URL`, `Data`, `Date`에는 `NS`가 없는 이유다. 예전에는 `NSURL`, `NSData`, `NSDate`였다.

### 그런데 왜 어떤 건 남아 있나 — 판단 기준

SE-0086이 남기는 기준을 명시한다.

> If the class is specifically for Objective-C, or inherently tied to the Objective-C runtime and NS namespace, keep NS prefix.

여기에 더해 **값 타입 대응물이 이미 있거나 예정된 경우**에도 접두사를 유지한다. 이름 충돌을 피하기 위해서다.

실무적으로는 세 부류로 나눠 보면 이해가 쉽다.

**① Objective-C 런타임에 묶인 것 — 접두사 유지**

`NSObject`, `NSException`, `NSAutoreleasePool` 등. Swift 네이티브 개념이 아니라 Objective-C 세계의 물건이다.

**② 값 타입 짝이 있어서 이름이 갈린 것 — 가장 흔한 경우**

Swift에는 같은 개념의 **값 타입**과 **참조 타입**이 짝을 이루는 경우가 많다. 이때 Swift 이름은 값 타입이 가져가고, 참조 타입 쪽이 `NS`를 유지한다.

| Swift 값 타입 (`struct`) | Objective-C 클래스 (`class`) |
| --- | --- |
| `String` | `NSString` |
| `Array` | `NSArray` |
| `Dictionary` | `NSDictionary` |
| `Data` | `NSData` |
| `Date` | `NSDate` |
| `URL` | `NSURL` |
| `AttributedString` | `NSAttributedString` |

앞의 것은 값 타입이라 복사되고, 뒤의 것은 참조 타입이라 공유된다. 이 차이는 [struct와 class](./struct-vs-class.md), [Swift 메모리 구조](./swift-memory-model.md)에서 다룬 그대로다.

**③ 아직 Swift 네이티브 대체물이 없는 것 — 이 예제가 여기 속한다**

`NSDataDetector`, `NSRegularExpression`, `NSTextCheckingResult`, `NSPredicate`, `NSCache` 등. Objective-C 클래스가 그대로 노출되어 있고 대응하는 Swift 타입이 만들어지지 않았다.

예제의 세 타입을 분류하면 이렇다.

| 타입 | 분류 | 비고 |
| --- | --- | --- |
| `NSDataDetector` | ③ | Swift 대체물 없음 |
| `NSTextCheckingResult` | ③ | 위와 한 세트 |
| `NSRange` | ②에 가까움 | `Range<String.Index>`가 Swift 방식 |

### `NS` 타입을 쓸 때 조심할 것들

접두사가 남아 있다는 건 **Objective-C의 사고방식이 함께 딸려 온다**는 뜻이다. Swift 코드에 섞어 쓸 때 마찰이 생기는 지점들이 있다.

**1. 참조 타입이다**

`NS`가 붙은 것은 대부분 `class`다. 대입해도 복사되지 않는다.

```swift
let a = NSMutableArray()
let b = a
b.add(1)
print(a.count)   // 1 — a도 바뀐다
```

**2. 문자열 인덱싱 모델이 다르다 — 예제의 `utf16.count`**

이게 가장 자주 물리는 지점이다.

`NSRange`는 `NSString`을 전제하고, `NSString`은 **UTF-16 코드 유닛**으로 길이를 센다. Swift의 `String.count`는 사람이 인식하는 **문자** 단위다.

```swift
let s = "안녕👋"
s.count            // 3
s.utf16.count      // 4  — 👋가 UTF-16에서 2 유닛
```

그래서 예제가 이렇게 쓴다.

```swift
range: NSRange(location: 0, length: text.utf16.count)
```

`text.count`로 바꾸면 이모지가 들어간 순간 범위가 어긋난다. 더 안전한 표현은 변환 이니셜라이저다.

```swift
NSRange(text.startIndex..., in: text)
```

자세한 내용은 [NSDataDetector 문서](./nsdatadetector-and-url-detection.md)에 있다.

**3. 비트 플래그를 `rawValue`로 넘긴다**

```swift
NSDataDetector(types: types.rawValue)
```

Objective-C의 `NS_OPTIONS` 비트 마스크가 그대로 노출된 형태다. Swift다운 API라면 `OptionSet`을 직접 받았을 것이다.

**4. 오류 처리가 `throws`로 변환되어 있다**

Objective-C의 `NSError **` 아웃 파라미터는 Swift에서 `throws`로 자동 변환된다.

> **Handling Errors in Swift:** In Swift, this API is imported as an initializer and is marked with the `throws` keyword to indicate that it throws an error in cases of failure.

그래서 예제가 `try?`를 쓴다. `try`/`try?`/`do-catch`의 선택 기준은 [Swift의 오류 처리 방식들](./swift-error-handling-forms.md)에 정리했다.

**5. 옵셔널이 느슨할 수 있다**

Objective-C에는 옵셔널 개념이 없어 nullability 표기가 없으면 암시적 언래핑 옵셔널(`!`)로 들어온다. 요즘 SDK는 대부분 표기되어 있지만, 오래된 API는 여전히 주의가 필요하다.

### 언제 `NS` 타입을 쓰나

**써야 할 때**

- Swift 네이티브 대체물이 아직 없을 때 — 이 예제의 `NSDataDetector`가 그렇다
- Objective-C 프레임워크와 직접 연동해야 할 때
- `NSCache`처럼 Swift에 동등한 것이 없는 기능이 필요할 때

**피해야 할 때**

- Swift 대응물이 있다면 그쪽을 쓴다. `NSString` 대신 `String`, `NSArray` 대신 `Array`, `NSURL` 대신 `URL`.
- 새 코드에서 `NSMutableArray`, `NSMutableDictionary`를 쓸 이유는 거의 없다.
- 정규식은 iOS 16부터 Swift 네이티브 `Regex`가 있다. 다만 데이터 탐지는 `NSDataDetector`뿐이다.

### 접두사로 출신 알아보기

| 접두사 | 프레임워크 | 예 |
| --- | --- | --- |
| `NS` | Foundation / AppKit (NeXTSTEP) | `NSDataDetector`, `NSObject` |
| `CF` | Core Foundation (C API) | `CFString`, `CFArray` |
| `CG` | Core Graphics | `CGFloat`, `CGRect` |
| `CA` | Core Animation | `CALayer` |
| `CI` | Core Image | `CIFilter` |
| `CL` | Core Location | `CLLocation` |
| `UI` | UIKit | `UIView`, `UIApplication` |
| `AV` | AVFoundation | `AVPlayer` |
| `SK` | SpriteKit / StoreKit | `SKScene` |

접두사가 없으면 대체로 **Swift 네이티브이거나 Swift용으로 정리된 타입**이라고 보면 된다. SwiftUI 타입에 접두사가 없는 이유이기도 하다.

### 정리

```text
NS = NeXTSTEP. Objective-C에 네임스페이스가 없어서 붙인 접두사.

Swift 3(SE-0086)에서 대거 제거됨
  NSBundle → Bundle,  NSURLSession → URLSession, ...

남아 있는 경우
  ① Objective-C 런타임에 묶인 것        NSObject, NSException
  ② 값 타입 짝이 이름을 가져간 것        NSString ↔ String
  ③ Swift 대체물이 아직 없는 것          NSDataDetector, NSRegularExpression  ← 이 예제

NS 타입을 쓸 때: 참조 타입 / UTF-16 인덱싱 / rawValue 비트 플래그 / throws 변환
```

## 학습 체크리스트

- [ ] `NSDataDetector`가 `class`인지 `struct`인지 확인한다.
- [ ] `NSMutableArray`를 두 변수에 담고 한쪽을 바꿔 양쪽에 반영되는지 본다.
- [ ] 같은 실험을 Swift `Array`로 해서 값 타입과 비교한다.
- [ ] `"안녕👋"`의 `count`와 `utf16.count`를 출력해 차이를 확인한다.
- [ ] `text.utf16.count`를 `text.count`로 바꾸고 이모지를 넣어 문제를 재현한다.
- [ ] `NSRange(text.startIndex..., in: text)`로 바꿔 동작이 같은지 확인한다.
- [ ] `NSString`으로 문자열을 만들어 `length`가 `utf16.count`와 같은지 확인한다.
- [ ] `types.rawValue`의 실제 숫자 값을 출력해 비트 플래그임을 확인한다.
- [ ] `[.link, .phoneNumber]`의 `rawValue`가 비트 OR 결과인지 계산해 본다.
- [ ] `try?`를 `do-catch`로 바꿔 어떤 오류가 나올 수 있는지 확인한다.
- [ ] `NSURL`과 `URL`을 서로 변환해 본다 (`as URL`, `as NSURL`).
- [ ] SE-0086 문서에서 접두사를 유지한 타입 목록을 훑고 기준을 설명한다.
- [ ] iOS 16의 Swift `Regex`로 URL을 찾아 보고 `NSRegularExpression`과 비교한다.

## 공식 참고 자료

- [Swift Evolution SE-0086: Drop NS Prefix in Swift Foundation](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0086-drop-foundation-ns.md)
- [Apple: Foundation](https://developer.apple.com/documentation/foundation)
- [Apple: NSDataDetector](https://developer.apple.com/documentation/foundation/nsdatadetector)
- [Apple: NSTextCheckingResult](https://developer.apple.com/documentation/foundation/nstextcheckingresult)
- [Apple: NSRange](https://developer.apple.com/documentation/foundation/nsrange)
- [Apple: NSString](https://developer.apple.com/documentation/foundation/nsstring)
- [Apple: NSObject](https://developer.apple.com/documentation/objectivec/nsobject)
- [Apple: URL](https://developer.apple.com/documentation/foundation/url)
- [Swift 공식 문서: Strings and Characters — Unicode](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/#Unicode)
- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
