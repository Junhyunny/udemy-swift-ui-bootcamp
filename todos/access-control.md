# Swift 접근 제어

## 질문이 나온 코드

`chapter-11/chapter-11/ContentView.swift`의 `@State private var red`와 접근 제어자를 생략한 `@Binding var value`

`chapter-140/chapter-140/ViewModels/PianoViewModel.swift`

```swift
private(set) var activeNotes: Set<MIDINoteNumber> = []
```

`private(set)`이 무슨 기능인지, setter를 **열어 준다**는 뜻인지가 추가 질문이다.

## 공부할 내용

- `private`: 둘러싼 선언과 같은 파일에 있는 해당 선언의 extension 내부에서 접근
- `fileprivate`: 선언된 source file 내부에서 접근
- `internal`: 같은 module 내부에서 접근하며, 대부분 선언의 기본 접근 수준
- `package`: 같은 package에 속한 module에서 접근
- `public`: 다른 module에서도 접근하지만 외부 subclass와 override는 제한
- `open`: class와 class member에만 적용되며 다른 module에서 subclass와 override도 허용
- 더 공개된 선언은 자신보다 덜 공개된 타입을 parameter나 return type으로 노출할 수 없다.
- 단일 app target에서는 기본 `internal`이 대체로 충분하고, 구현 세부 사항을 숨길 때 `private` 또는 `fileprivate`를 사용한다.

### `private(set)` — setter만 따로 좁히기

결론부터 말하면 **여는 것이 아니라 좁히는 것**이다. 이름 그대로 "set은 private으로" 라는 뜻이다.

```swift
private(set) var activeNotes: Set<MIDINoteNumber> = []
```

| 동작 | 접근 수준 |
|---|---|
| 읽기(get) | 프로퍼티에 적힌 수준 그대로. 여기서는 생략했으므로 `internal` |
| 쓰기(set) | 괄호 안에 적은 수준. 여기서는 `private` |

즉 **"밖에서는 읽기만, 값 변경은 이 타입 안에서만"**이다. 다음과 같이 두 줄로 쓴 것과 같은 효과다.

```swift
// private(set) var activeNotes ... 와 같은 의미
internal var activeNotes: Set<MIDINoteNumber> {
    get { _activeNotes }
}
private var _activeNotes: Set<MIDINoteNumber> = []
```

Swift에서는 **setter의 수준이 getter보다 더 공개될 수 없다.** 그래서 `public private(set)`은 되지만 `private public(set)`은 컴파일되지 않는다.

```swift
public private(set) var count = 0    // 읽기는 public, 쓰기는 private
internal private(set) var items = [] // 읽기는 internal, 쓰기는 private
public internal(set) var name = ""   // 읽기는 public, 쓰기는 같은 모듈 안에서만
```

`get`에만 따로 수준을 주는 문법은 없다. 괄호를 붙일 수 있는 것은 `set`뿐이다.

`PianoViewModel`에서 이렇게 쓴 이유가 분명하다.

```swift
private(set) var activeNotes: Set<MIDINoteNumber> = []

func notePressed(_ note: PianoNote) { ... activeNotes.insert(...) }
func noteReleased(_ note: PianoNote) { ... activeNotes.remove(...) }
```

- View는 `isNoteActive(_:)`로 상태를 **읽기만** 한다.
- 상태 변경은 반드시 `notePressed` / `noteReleased`를 거친다.
- 그래서 "화면에 눌린 것으로 보이는데 소리는 안 나는" 어긋남이 구조적으로 막힌다. 집합에 넣는 코드와 소리를 내는 코드가 한 메서드 안에 함께 있기 때문이다.

`var`를 그냥 열어 두면 외부에서 `viewModel.activeNotes.insert(60)`이 가능해지고, 이때 오디오는 울리지 않는다. `private(set)`은 그 경로를 컴파일 단계에서 없앤다.

참고로 `let`은 처음부터 변경할 수 없으므로 `private(set)`을 붙일 수 없고 붙일 이유도 없다.

## 학습 체크리스트

- [ ] 여섯 접근 수준을 공개 범위 순서대로 설명한다.
- [ ] `private`와 `fileprivate`를 서로 다른 extension과 source file에서 비교한다.
- [ ] `public`과 `open`의 차이를 class 상속 예제로 확인한다.
- [ ] `@testable import`가 test target에 internal 선언을 노출하는 방식을 확인한다.
- [ ] `private(set)`이 setter를 좁히는 것임을 외부에서 대입해 보며 오류로 확인한다.
- [ ] `public private(set)`과 `public internal(set)`의 차이를 설명한다.
- [ ] `private public(set)`이 왜 컴파일되지 않는지 설명한다.
- [ ] `private(set)`을 떼고 View에서 상태를 직접 바꿔 보며 무엇이 깨지는지 확인한다.

## 참고 자료

- [The Swift Programming Language: Access Control](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/accesscontrol/)
- [The Swift Programming Language: Declarations](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/declarations/)
- [The Swift Programming Language: Attributes (`@testable`)](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/attributes/)
