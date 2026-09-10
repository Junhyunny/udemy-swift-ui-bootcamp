# GameKit과 GameplayKit — 게임 서비스와 게임 로직 도구

## 질문이 나온 코드

`chapter-104/chapter-104/GameViewModel.swift`

```swift
import GameKit

private let aiOpponent = GKRandomDistribution(
    lowestValue: 0,
    highestValue: 2
)
```

## 공부할 내용

### 먼저 구분할 것: `GKRandomDistribution`은 GameplayKit 타입이다

현재 코드의 `GKRandomDistribution`은 이름이 `GK`로 시작하지만 **GameKit이 아니라 GameplayKit 프레임워크**에 속한다. 따라서 이 기능의 의도를 가장 정확하게 나타내는 import는 다음과 같다.

```swift
import GameplayKit
```

GameKit과 GameplayKit은 이름이 비슷하지만 해결하는 문제가 다르다.

| 프레임워크 | 중심 역할 | 대표 기능 |
|---|---|---|
| GameKit | 플레이어와 Game Center 서비스 연결 | 인증, 리더보드, 도전 과제, 친구, 매치메이킹, 멀티플레이 |
| GameplayKit | 게임 규칙과 시뮬레이션에 재사용하는 로직 | 난수, 상태 머신, 에이전트, 경로 탐색, 규칙 시스템 |

### GameKit은 언제 사용하는가

GameKit은 Apple의 Game Center 기능을 앱에 통합할 때 사용한다.

- 로컬 플레이어 인증과 Game Center 접근
- 점수를 리더보드에 제출하고 순위 표시
- 도전 과제 진행률 제출과 표시
- 실시간 또는 턴 기반 멀티플레이 매치 구성
- 플레이어 초대, 매치메이킹, 친구 관련 기능
- Game Center 접근 지점과 대시보드 표시

가위바위보를 한 기기에서 AI와 플레이하는 현재 기능만으로는 GameKit이 필수는 아니다. 온라인 상대를 찾거나 승리 횟수를 리더보드에 올리는 기능을 추가할 때 GameKit이 적합하다.

```swift
import GameKit

GKLocalPlayer.local.authenticateHandler = { viewController, error in
    // 필요한 인증 화면 표시 또는 인증 결과 처리
}
```

### GameplayKit은 언제 사용하는가

GameplayKit은 게임의 UI나 Game Center 서비스가 아니라 게임 내부의 공통 알고리즘을 제공한다.

- 재현 가능하거나 분포를 조절할 수 있는 난수 생성
- 상태 머신으로 캐릭터·게임 상태 전환 관리
- 그래프 기반 경로 탐색
- 에이전트의 이동과 군집 행동
- 규칙 시스템과 의사 결정
- Minimax 기반 게임 전략

현재 코드는 상대의 수를 균등하게 고르기 위해 GameplayKit의 난수 분포를 사용한다.

```swift
import GameplayKit

let distribution = GKRandomDistribution(
    lowestValue: 0,
    highestValue: 2
)

let index = distribution.nextInt()
let move = Move.allCases[index]
```

`lowestValue`와 `highestValue`는 모두 포함된다. 따라서 위 분포는 `0`, `1`, `2` 중 하나를 반환하며, 사례가 세 개인 `Move.allCases`의 인덱스와 맞는다.

### 단순 난수라면 표준 라이브러리도 가능하다

현재 요구처럼 배열에서 한 항목을 무작위로 고르기만 한다면 GameplayKit 없이 Swift 표준 라이브러리를 사용할 수도 있다.

```swift
let move = Move.allCases.randomElement()!
```

또는 인덱스가 필요하면 다음처럼 쓸 수 있다.

```swift
let index = Int.random(in: Move.allCases.indices)
```

GameplayKit은 특정 분포, seed 기반 재현성, 여러 난수 생성기를 교체하는 설계가 필요할 때 더 의미가 크다. 단순 임의 선택에는 `randomElement()`가 의도를 더 직접적으로 표현한다.

### 배열 크기와 숫자 범위를 중복하지 않기

현재 구현의 `highestValue: 2`는 `Move` 사례 수가 세 개라는 사실을 별도로 하드코딩한다. 사례가 추가되면 범위와 배열이 어긋날 수 있다.

```swift
let moves = Move.allCases
let distribution = GKRandomDistribution(
    lowestValue: moves.startIndex,
    highestValue: moves.index(before: moves.endIndex)
)
```

이 예제에서는 `randomElement()`가 이 중복 자체를 제거하므로 더 단순하다.

## 체크리스트

- [ ] GameKit과 GameplayKit이 각각 외부 게임 서비스와 내부 게임 로직 중 무엇을 담당하는지 설명한다.
- [ ] 현재 파일의 `import GameKit`을 `import GameplayKit`으로 바꾸고 빌드한다.
- [ ] `GKRandomDistribution`의 최솟값과 최댓값이 모두 포함되는지 확인한다.
- [ ] 상대 수 선택을 `Move.allCases.randomElement()`로 바꿔 비교한다.
- [ ] GameKit이 필요해지는 기능을 리더보드, 도전 과제, 멀티플레이 중 하나로 설명한다.
- [ ] enum 사례 수를 바꿨을 때 하드코딩한 `highestValue`가 왜 위험한지 설명한다.

## 공식 참고 자료

- [Apple: GameKit](https://developer.apple.com/documentation/gamekit)
- [Apple: Enabling and configuring Game Center](https://developer.apple.com/documentation/gamekit/enabling-and-configuring-game-center)
- [Apple: GKLocalPlayer](https://developer.apple.com/documentation/gamekit/gklocalplayer)
- [Apple: GameplayKit](https://developer.apple.com/documentation/gameplaykit)
- [Apple: GKRandomDistribution](https://developer.apple.com/documentation/gameplaykit/gkrandomdistribution)
- [Apple: RandomNumberGenerator](https://developer.apple.com/documentation/swift/randomnumbergenerator)
- [Apple: Collection.randomElement()](https://developer.apple.com/documentation/swift/collection/randomelement())
