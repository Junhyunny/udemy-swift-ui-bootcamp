# Chapter 109. SwiftData와 Core Data

원래 메모의 사실 여부를 Apple 공식 문서와 WWDC 세션을 기준으로 다시 확인했다. 자세한 개념, 비교 예제, 선택 기준과 학습 자료는 [Core Data와 SwiftData 학습 TODO](../todos/core-data-vs-swiftdata.md)에 정리했다.

## 원래 메모 검증

| 원래 주장 | 판정 | 보정한 설명 |
|---|---|---|
| 둘 다 iOS 데이터 영속성 기능이다 | 대체로 맞음 | 둘 다 객체 그래프를 모델링·조회·변경하고 저장소에 영속화한다. 단순한 SQLite wrapper나 데이터베이스 자체로만 이해하면 부족하다. |
| Core Data는 약 20년 된 성숙한 기술이다 | 맞음 | Core Data는 2005년 OS X Tiger에서 등장했고 iPhone OS 3.0부터 iPhone 앱에서도 사용할 수 있었다. |
| SwiftData는 iOS 17에서 소개되었고 사용하기 쉬운 API를 제공한다 | 맞음 | SwiftData는 WWDC23에서 소개되었다. iOS 17, macOS 14, tvOS 17, watchOS 10부터 사용할 수 있고 Swift macro와 SwiftUI 통합을 제공한다. |
| SwiftData는 스마트 동시성 덕분에 성능이 좋다 | 부정확함 | `ModelActor`와 Swift concurrency 통합은 데이터 접근의 격리와 안전한 구조화를 돕는다. 기본 model executor는 직렬 실행되며, 이것만으로 Core Data보다 빠르다는 보장은 없다. |
| Core Data만 복잡한 쿼리와 관계를 지원한다 | 부정확함 | SwiftData도 `#Predicate`, `FetchDescriptor`, 정렬, fetch limit, prefetch, `@Relationship`과 delete rule을 지원한다. Core Data가 더 오래되고 세밀한 API를 폭넓게 제공한다는 설명이 정확하다. |
| SwiftData는 iOS 17 이상만 가능하다 | 맞음 | SwiftData의 최초 지원 버전은 iOS 17이다. 이후 추가된 API는 iOS 18 이상처럼 더 높은 버전을 요구할 수도 있다. |
| Core Data는 모든 iOS에서 사용 가능하다 | 표현이 과함 | 최초 iPhone OS부터는 아니고 iPhone OS 3.0부터 지원한다. 오늘날 실제로 유지되는 거의 모든 deployment target을 포괄한다는 의미로는 맞다. |
| 복잡한 데이터 모델이면 Core Data다 | 선택 기준으로 부족함 | 모델이 복잡하다는 이유만으로 결정할 수 없다. 필요한 query 표현력, migration, batch 작업, 동기화, 기존 저장소, 최소 OS를 API별로 확인해야 한다. |
| 효율적인 메모리 관리가 필요하면 Core Data다 | 근거 없는 일반화 | Core Data는 faulting, batch fetch 등 성숙한 조절 수단이 있다. 그러나 실제 메모리와 속도는 모델·query·데이터 양에 따라 측정해야 하며 프레임워크 이름만으로 결정할 수 없다. |
| Objective-C를 다뤄야 하면 Core Data다 | 맞음 | SwiftData는 Swift macro와 Swift 타입 중심이다. Objective-C 모델·코드와의 통합이 필요하면 Core Data가 적합하다. 원문의 `Object-C`는 `Objective-C`가 정확한 이름이다. |
| 단순 앱이며 최신 SwiftUI만 지원하면 SwiftData다 | 합리적인 출발점 | iOS 17 이상이고 Swift 중심의 새 앱이라면 SwiftData가 자연스러운 기본 후보다. 단순함만이 아니라 요구 기능과 migration 계획도 확인해야 한다. |
| Core Data에만 있는 기능이 꽤 있다 | 방향은 맞지만 고정 목록은 위험 | Core Data의 저수준·고급 API 범위가 더 넓다. 다만 SwiftData가 OS 릴리스마다 확장되므로 필요한 기능을 현재 SDK와 최소 OS 기준으로 비교해야 한다. |

## 바로잡은 핵심 결론

```text
새 Swift 중심 앱 + iOS 17 이상 + SwiftUI 긴밀 통합
    → SwiftData를 먼저 검토

낮은 최소 OS / 기존 Core Data 저장소 / Objective-C / 검증된 고급 API 필요
    → Core Data를 먼저 검토

성능·메모리·복잡성
    → 이름으로 결정하지 말고 실제 모델과 query로 측정
```

둘 중 하나를 고르는 핵심 질문은 “앱이 단순한가?”가 아니라 다음과 같다.

1. 지원해야 하는 최소 OS는 무엇인가?
2. 기존 Core Data 모델과 저장소가 있는가?
3. 필요한 관계, query, migration, batch 작업, CloudKit 동기화를 선택한 API가 지원하는가?
4. 백그라운드 import와 동시성 경계를 어떻게 구성할 것인가?
5. 실제 데이터 규모에서 속도와 메모리를 측정했는가?
