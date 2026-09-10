# Chapter 110. Core Data와 SwiftData 선택 기준

이 문서는 두 persistence framework의 특징, 장단점, 사용 시점과 용량·성능 제약을 빠르게 판단하기 위한 요약이다. 기초 구조부터 migration까지 학습하려면 [Core Data와 SwiftData TODO](../todos/core-data-vs-swiftdata.md)를 보고, `Grocery` model의 class와 `final` 질문은 [SwiftData model TODO](../todos/swiftdata-model-class-and-final.md)를 본다.

## 한 문장으로 구분

- **Core Data**: 오래 운영되어 저수준 제어와 고급 기능, 이전 OS 및 기존 프로젝트 대응이 강한 객체 그래프·영속성 프레임워크다.
- **SwiftData**: Swift macro, Observation, Swift concurrency와 SwiftUI에 맞춘 현대적인 영속성 API다.

둘 다 단순 데이터베이스 wrapper가 아니다. model identity, relationship, change tracking, query, undo, save와 migration을 함께 다룬다.

## 핵심 구조 비교

| 역할 | Core Data | SwiftData |
|---|---|---|
| 모델 | `.xcdatamodeld`, `NSManagedObject` | `@Model` class |
| 전체 설정 | `NSPersistentContainer` | `ModelContainer` |
| 작업 단위 | `NSManagedObjectContext` | `ModelContext` |
| query | `NSFetchRequest`, `NSPredicate` | `FetchDescriptor`, `#Predicate` |
| SwiftUI 연동 | `@FetchRequest` | `@Query` |
| 동시성 | context queue, `perform` | context isolation, `ModelActor` |
| migration | model version, mapping | `VersionedSchema`, `SchemaMigrationPlan` |
| 최초 iOS 지원 | iPhone OS 3.0 | iOS 17 |

```text
Model
  ↓
Container
  ↓
Context  ← fetch / insert / update / delete
  ↓ save
Persistent Store
```

API 이름은 달라도 둘 다 이 흐름을 가진다.

## Core Data

### 특징

- entity, attribute, relationship으로 객체 그래프를 정의한다.
- `NSManagedObjectContext`가 identity와 변경을 추적한다.
- SQLite와 in-memory 등 persistent store 구성을 제공한다.
- faulting, batch update/delete, persistent history, fetched results controller 등 세밀한 API가 축적되어 있다.
- Objective-C와 Swift 양쪽에서 사용할 수 있다.

### 장점

- 긴 운영 역사와 많은 migration·성능 튜닝 사례가 있다.
- 낮은 deployment target을 지원한다.
- 대량 데이터 처리와 context 구성에 세밀한 제어가 가능하다.
- 기존 Core Data model과 store를 그대로 활용할 수 있다.
- Objective-C 또는 `NSManagedObject` 기반 모듈과 통합하기 쉽다.

### 단점

- model editor, generated class, context와 queue 규칙 등 배울 개념이 많다.
- 문자열 기반 `NSPredicate`를 쓰면 일부 오류가 runtime까지 늦게 드러날 수 있다.
- SwiftUI와 연결할 때 SwiftData보다 보일러플레이트가 많아질 수 있다.
- context를 잘못된 queue에서 사용하거나 object를 queue 사이에 넘기면 concurrency 문제가 생긴다.

### 먼저 선택할 시점

- iOS 16 이하를 지원해야 한다.
- 이미 운영 중인 Core Data store와 migration history가 있다.
- Objective-C 연동이 필요하다.
- 특정 Core Data batch API, persistent history, fetched results controller 또는 store 제어가 핵심 요구사항이다.
- 팀이 Core Data 운영·진단 경험을 이미 갖고 있다.

## SwiftData

### 특징

- `@Model` macro로 Swift class를 persistence model로 만든다.
- `ModelContainer`와 `ModelContext`로 schema와 작업 단위를 관리한다.
- `#Predicate`와 key path 기반 sort로 compile-time type checking을 활용한다.
- SwiftUI의 `@Query`, `.modelContainer`, environment와 직접 통합된다.
- `ModelActor`로 persistence 작업을 actor isolation 안에 구성할 수 있다.

### 장점

- Swift 코드 중심이라 model을 시작하기 쉽다.
- Observation과 SwiftUI 화면 갱신의 연결이 자연스럽다.
- predicate와 model property가 type-safe하다.
- 간단한 새 앱에서는 persistence stack 설정 코드가 적다.
- 최신 OS에서 index, uniqueness, history, custom store, inheritance 같은 기능이 계속 확장되고 있다.

### 단점

- 기본 기능도 iOS 17 이상이 필요하고 새 API는 더 높은 OS를 요구한다.
- Core Data보다 공개 API와 운영 사례의 역사가 짧다.
- 필요한 고급 기능이 특정 OS 버전에서 아직 없거나 표현 방식이 다를 수 있다.
- macro가 생성한 코드와 저장소 오류를 처음 진단할 때 내부 흐름이 덜 보일 수 있다.
- 단순한 문법이 migration, relationship ownership, concurrency 설계까지 자동으로 해결하지는 않는다.

### 먼저 선택할 시점

- 새 Swift 중심 앱이고 최소 OS가 iOS 17 이상이다.
- SwiftUI의 `@Query`와 Observation 통합이 생산성에 도움이 된다.
- 필요한 query, migration, batch 처리와 CloudKit 기능이 목표 OS에서 지원된다.
- 기존 Core Data 호환성보다 새 코드의 단순성과 type safety가 중요하다.

## 제약사항: 용량

### “최대 몇 MB인가?”에는 하나의 숫자로 답할 수 없다

Core Data와 SwiftData에는 모든 앱에 적용되는 단일 고정 용량 제한이 공개되어 있지 않다. 실제 제약은 다음 항목의 조합이다.

- 기기의 남은 디스크 공간
- 사용하는 persistent store와 schema
- row 수와 relationship 밀도
- index가 차지하는 공간
- binary data 크기
- migration 중 필요한 추가 여유 공간
- CloudKit 사용 시 iCloud quota와 네트워크

```text
Store가 디스크에 들어간다
    ≠
그 데이터를 한 번에 메모리에 올려도 안전하다
```

### 이미지와 영상

큰 이미지를 model의 `Data`에 직접 넣으면 fetch와 migration이 무거워질 수 있다.

- Core Data: Allows External Storage 검토
- SwiftData: `@Attribute(.externalStorage)` 검토
- 대용량 원본: 파일 시스템에 저장하고 model에는 URL과 metadata 저장 검토

external storage도 만능은 아니다. model 삭제와 실제 파일 삭제의 일관성, backup, orphan file 정리를 설계해야 한다.

## 제약사항: 메모리와 성능

### 어느 프레임워크가 항상 빠른가

그런 결론은 낼 수 없다. `ModelActor`는 동시성 안전성을 구조화하지만 자동 성능 향상을 보장하지 않는다. Core Data의 성숙한 faulting도 잘못된 query와 N+1 관계 접근까지 해결하지는 않는다.

성능은 다음 항목에 더 크게 좌우된다.

| 문제 | 확인할 것 |
|---|---|
| 느린 검색 | predicate가 store에서 실행되는가, index가 필요한가 |
| 높은 메모리 | fetch limit, paging, batch size를 적용했는가 |
| 스크롤 버벅임 | 관계를 row마다 지연 fetch하는 N+1이 있는가 |
| 저장 지연 | 너무 자주 save하거나 transaction이 지나치게 큰가 |
| UI 정지 | main context에서 대량 import하는가 |
| 큰 store | binary와 index, history, migration 임시 공간이 큰가 |

### 최소한 측정할 지표

```text
cold launch
첫 fetch / 반복 fetch
insert + save
대량 import
migration 시간
peak memory
store file 크기
```

같은 schema와 fixture, 같은 release build에서 Instruments와 signpost로 측정한다. 앱 이름이나 framework 이름만 보고 성능을 예측하지 않는다.

## 기능 제약은 최소 OS와 함께 본다

SwiftData 자체는 iOS 17부터지만 모든 기능이 iOS 17에 있는 것은 아니다.

- iOS 17: 기본 `@Model`, container, context, query, migration
- iOS 18: compound uniqueness, `#Index`, history와 custom store 등 확장
- iOS 26: model class inheritance 등 추가 확장

따라서 최신 Xcode에서 API가 보인다는 이유만으로 deployment target에서 사용할 수 있다고 판단하면 안 된다. `@available`, Apple 문서의 availability와 실제 target을 함께 확인한다.

Core Data도 오래된 OS에서 API 전체가 동일한 것은 아니다. 필요한 개별 기능의 availability를 확인한다.

## 둘 다 적합하지 않을 수 있는 경우

| 요구사항 | 먼저 검토할 도구 |
|---|---|
| 작은 설정값 | `UserDefaults`, `@AppStorage` |
| 비밀 정보 | Keychain |
| 큰 파일 원본 | 파일 시스템 |
| 서버가 원본인 데이터 | 네트워크 client + cache 정책 |
| SQL을 직접 제어해야 함 | SQLite 계층 또는 별도 database library |

Core Data나 SwiftData를 쓴다고 서버 database를 대체하거나 여러 사용자의 중앙 데이터 저장소가 생기는 것은 아니다.

## 최종 선택 체크리스트

1. 최소 지원 OS가 iOS 17 이상인가?
2. 기존 Core Data store와 migration을 유지해야 하는가?
3. Objective-C 연동이 필요한가?
4. 필요한 query와 relationship을 실제 코드로 검증했는가?
5. batch, history, CloudKit, custom store 요구사항이 있는가?
6. 예상 데이터 양으로 성능과 peak memory를 측정했는가?
7. 이전 버전 store로 migration을 테스트했는가?

```text
1~3에서 Core Data 제약이 있음
    → Core Data 우선 검토

새 SwiftUI 앱이고 목표 OS에서 요구 기능 충족
    → SwiftData 우선 검토

용량·성능이 핵심
    → 작은 benchmark 후 결정
```

## 관련 학습 문서

- [Core Data와 SwiftData — 구조, query, 관계, 동시성, migration](../todos/core-data-vs-swiftdata.md)
- [SwiftData `@Model`은 왜 class이고 `final`은 필수인가](../todos/swiftdata-model-class-and-final.md)
- [SwiftData `@Query` — 실행 시점, 조건·정렬과 query 디버깅](../todos/swiftdata-query-and-debugging.md)
- [SwiftData container, context, configuration과 in-memory 저장소](../todos/swiftdata-container-context-and-configuration.md)
- [SwiftData 저장 위치, 보안, 용량과 성능](../todos/swiftdata-storage-security-and-performance.md)
- [SwiftData relationship과 연관 데이터 조회](../todos/swiftdata-relationships-and-fetching.md)

## 공식 참고 자료

- [Apple: Core Data](https://developer.apple.com/documentation/coredata)
- [Apple: SwiftData](https://developer.apple.com/documentation/swiftdata)
- [Apple: Core Data performance](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/Performance.html)
- [Apple WWDC24: What’s new in SwiftData](https://developer.apple.com/videos/play/wwdc2024/10137/)
- [Apple WWDC25: SwiftData — Dive into inheritance and schema migration](https://developer.apple.com/videos/play/wwdc2025/291/)
