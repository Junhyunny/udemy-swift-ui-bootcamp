# SwiftData 저장 위치, 보안, 용량과 성능

## 질문이 나온 코드

`chapter-110/chapter-110/chapter_110App.swift`

```swift
.modelContainer(for: Grocery.self)
```

이 한 줄을 보고 생긴 질문은 다음과 같다.

- 데이터는 memory와 file system 중 어디에 저장되는가?
- 저장 구조와 실제 파일 위치는 어떻게 확인하는가?
- 저장 용량에 제한이 있는가?
- 자주 읽고 쓰면 느려지는가?
- 데이터가 자동으로 암호화되는가?
- 외부에서 store 파일을 열어 내용을 볼 수 있는가?

## 공부할 내용

### 기본값은 memory가 아니라 persistent store다

```swift
.modelContainer(for: Grocery.self)
```

`inMemory`를 지정하지 않은 기본 구성은 save된 데이터를 앱 실행이 끝난 뒤에도 보존하는 persistent store를 사용한다.

```swift
.modelContainer(for: Grocery.self, inMemory: true)
```

이렇게 명시해야 테스트·Preview에 적합한 memory-only 구성이 된다. in-memory store는 container가 사라지면 데이터도 사라진다.

### 지원되는 방법으로 store URL 확인하기

기본 파일명을 추측하지 말고 `ModelConfiguration.url`을 확인한다.

```swift
for configuration in modelContext.container.configurations {
    print("name:", configuration.name)
    print("url:", configuration.url)
    print("in memory:", configuration.isStoredInMemoryOnly)
}
```

기본 persistent store는 앱 sandbox의 container 아래에 놓인다. simulator에서는 출력된 URL을 Finder나 terminal로 살펴볼 수 있다. 실제 device에서는 앱 container 접근 권한과 Data Protection 상태의 영향을 받는다.

저장소 내부 파일명, SQLite table 이름과 schema는 SwiftData의 안정적인 공개 API로 취급하지 않는다. 내부 store를 직접 SQL로 수정하면 change tracking, relationship, migration metadata가 깨질 수 있다.

### 원하는 URL에 별도 persistent store 만들기

```swift
let storeURL = URL.applicationSupportDirectory
    .appending(path: "Groceries.store")

let configuration = ModelConfiguration(
    "Groceries",
    schema: Schema([Grocery.self]),
    url: storeURL
)

let container = try ModelContainer(
    for: Grocery.self,
    configurations: configuration
)
```

Application Support 같은 persistent data 위치를 사용하고, temporary 또는 cache directory와 생명주기를 혼동하지 않는다. custom URL을 쓸 때 directory 생성, backup 정책과 오류 복구도 함께 설계한다.

### 저장 흐름

```text
Grocery instance 변경
        │
        ▼
ModelContext change tracking
        │
        │ save / autosave
        ▼
ModelContainer configuration
        │
        ▼
Persistent store files
        │
        ▼
Device file system
```

property를 바꿀 때마다 disk에 즉시 한 row가 확정 저장된다고 가정하지 않는다. context가 변경을 추적하고 save 경계에서 store에 반영한다. SQLite 계열 store는 transaction과 WAL 같은 여러 보조 파일을 사용할 수 있으므로 main 파일 하나만 복사하는 방식도 안전한 backup이라고 단정할 수 없다.

### 용량에 고정된 한 숫자는 없다

Apple은 SwiftData 전체에 공통인 “최대 100 MB” 같은 단일 store 한도를 제시하지 않는다. 실제 제약은 다음에 달려 있다.

- device의 남은 disk 공간
- persistent store 구현
- row와 relationship 수
- 문자열과 binary data 크기
- index와 history가 차지하는 공간
- migration 중 원본과 새 store를 유지할 여유 공간
- CloudKit 사용 시 별도의 quota와 network 비용

중요한 구분은 다음과 같다.

```text
disk store 전체 크기
memory working set
한 query의 결과 크기
CloudKit 동기화 크기

서로 다른 제약이다.
```

수백만 row를 disk에 기록할 수 있는지와 그 row를 한 배열로 fetch해 화면에 표시할 수 있는지는 전혀 다른 문제다.

### 큰 이미지와 영상 저장

작은 thumbnail이나 payload에는 `Data`가 편리하지만 큰 원본을 model row에 직접 넣으면 query, save, migration과 backup 비용이 커질 수 있다.

```swift
@Model
final class Photo {
    @Attribute(.externalStorage)
    var imageData: Data
}
```

`.externalStorage`는 framework가 binary를 store 밖에 둘 수 있게 하는 힌트다. 크기 기준이나 정확한 파일 배치를 앱의 계약으로 가정해서는 안 된다.

대용량 미디어는 다음 구조도 검토한다.

```text
SwiftData model
 ├── file identifier
 ├── relative URL
 ├── content type
 ├── byte size
 └── checksum

File system
 └── original media file
```

이 구조는 파일 streaming과 cache 정책에 유리하지만 model transaction과 file operation이 하나의 원자적 transaction이 아니므로 실패 시 정리 전략이 필요하다.

### “자동 암호화”를 세 층으로 나누기

보안은 한 단어로 묶으면 오해하기 쉽다.

```text
1. App Sandbox
   다른 일반 앱의 container 접근 제한

2. iOS Data Protection
   device lock 상태와 file encryption key 보호

3. Database field-level encryption
   store 파일을 얻어도 특정 값을 별도 key 없이는 읽지 못하게 함
```

#### App Sandbox

일반적인 다른 앱은 앱 sandbox 안의 store 파일을 직접 열 수 없다. 하지만 이것은 database 내용 자체를 별도 암호로 암호화했다는 뜻이 아니다.

#### Data Protection

iOS는 앱 파일에 Data Protection을 적용한다. protection class는 앱과 파일 설정, device lock 상태에 따라 접근 가능 시점이 달라진다. Core Data는 persistent store file protection option을 제공하며, SwiftData에서 custom store 보안 요구가 있다면 지원되는 configuration과 파일 보호 정책을 목표 OS에서 검증해야 한다.

#### 민감 필드의 별도 보호

비밀번호, 인증 token, encryption key는 SwiftData나 Core Data의 일반 attribute에 평문으로 저장하지 않고 Keychain을 사용한다.

의료·금융처럼 store 파일을 획득한 공격자에게도 내용을 숨겨야 한다면 다음을 별도로 설계한다.

- 민감 필드 application-level encryption
- key를 Keychain 또는 Secure Enclave 기반 정책으로 관리
- key rotation과 복구
- 검색·정렬해야 하는 암호화 필드의 제약
- backup과 CloudKit 동기화 경계

SwiftData의 `@Attribute(.allowsCloudEncryption)` 같은 CloudKit 관련 옵션을 로컬 store 전체 암호화와 같은 것으로 오해하면 안 된다.

### 외부에서 store를 열어 볼 수 있는가

상황에 따라 다르다.

| 상황 | 접근 가능성 |
|---|---|
| 다른 sandboxed iOS 앱 | 일반적으로 직접 접근 불가 |
| 개발자가 simulator app container 확인 | 가능 |
| Xcode로 개발 device container 다운로드 | 개발·권한 조건에서 가능 |
| device가 잠기고 Data Protection key 사용 불가 | protection class에 따라 제한 |
| 공격자가 잠금 해제된 app container 또는 backup 획득 | store 내용 노출 가능성을 고려해야 함 |

따라서 “sandbox에 있으니 비밀 데이터도 안전하다” 또는 “SQLite이니 누구나 연다” 둘 다 과도한 단정이다. 위협 모델을 정하고 sandbox, file protection, field encryption, Keychain을 구분한다.

### 자주 접근하면 얼마나 느린가

고정된 시간으로 답할 수 없다. 다음 요인이 query와 save 비용을 결정한다.

- predicate가 store에서 실행 가능한가?
- 정렬·검색 필드에 적절한 index가 있는가?
- fetch 결과와 materialize되는 model 수는 얼마인가?
- relationship을 반복 접근해 N+1 query가 생기는가?
- 한 row마다 save하는가, transaction으로 묶는가?
- 대량 import를 main context에서 수행하는가?
- store가 migration 또는 CloudKit history를 처리 중인가?

```swift
var descriptor = FetchDescriptor<Grocery>(
    sortBy: [SortDescriptor(\Grocery.name)]
)
descriptor.fetchLimit = 100

let page = try modelContext.fetch(descriptor)
```

“읽기 횟수” 자체보다 불필요하게 넓은 fetch와 main actor를 오래 점유하는 작업이 UI 성능에 더 직접적인 문제가 된다.

### 성능 측정 계획

같은 release build와 고정 fixture를 사용해 다음을 측정한다.

| 시나리오 | 지표 |
|---|---|
| 1만 건 insert 후 한 번 save | 총 시간, peak memory, store 증가량 |
| 1건마다 save | 위 결과와 비교 |
| 전체 fetch | first fetch, peak memory |
| 100건 limit/paging | 응답 시간, 스크롤 중 memory |
| index 전후 검색 | p50/p95 query 시간 |
| relationship 목록 | query 횟수, N+1 여부 |
| V1→V2 migration | 소요 시간, 추가 disk, 실패 복구 |

Instruments의 Time Profiler, Allocations, Core Data 관련 instrument와 signpost를 함께 사용한다. simulator 결과만으로 device I/O 성능을 확정하지 않고 실제 지원 device에서도 측정한다.

## 체크리스트

- [ ] 기본 configuration의 URL과 `isStoredInMemoryOnly`를 출력한다.
- [ ] app 재실행 후 persistent store와 in-memory store의 차이를 확인한다.
- [ ] store 파일을 직접 수정하면 안 되는 이유를 change tracking과 migration 관점에서 설명한다.
- [ ] disk 용량, working set, query 결과, CloudKit quota를 서로 구분한다.
- [ ] 큰 이미지를 직접 `Data`, `.externalStorage`, 파일 URL 방식으로 각각 저장해 비교한다.
- [ ] App Sandbox, Data Protection, field-level encryption의 차이를 설명한다.
- [ ] 비밀번호와 token은 Keychain에 저장해야 하는 이유를 설명한다.
- [ ] 전체 fetch와 100건 fetch의 시간·peak memory를 측정한다.
- [ ] row마다 save하는 방식과 한 transaction save를 비교한다.
- [ ] simulator와 실제 device의 결과를 비교한다.

## 공식 참고 자료

- [Apple: ModelConfiguration](https://developer.apple.com/documentation/swiftdata/modelconfiguration)
- [Apple: ModelConfiguration.url](https://developer.apple.com/documentation/swiftdata/modelconfiguration/url)
- [Apple: ModelConfiguration.isStoredInMemoryOnly](https://developer.apple.com/documentation/swiftdata/modelconfiguration/isstoredinmemoryonly)
- [Apple: SwiftData Attribute externalStorage](https://developer.apple.com/documentation/swiftdata/schema/attribute/option/externalstorage)
- [Apple: Reducing your app’s memory use](https://developer.apple.com/documentation/xcode/reducing-your-app-s-memory-use)
- [Apple: Core Data performance](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/Performance.html)
- [Apple: FileProtectionType](https://developer.apple.com/documentation/foundation/fileprotectiontype)
- [Apple Platform Security: Data Protection overview](https://support.apple.com/guide/security/data-protection-overview-secf6276da8a/web)
- [Apple: Keychain Services](https://developer.apple.com/documentation/security/keychain-services)
