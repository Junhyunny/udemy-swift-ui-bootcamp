# `onChange`의 문법 — `oldValue`, `newValue`는 무엇이고 안 써도 되는가

## 질문이 나온 코드

`chapter-50/chapter-50/ContentView.swift`

```swift
TextEditor(text: $text)
    .onChange(of: text) { oldValue, newValue in
        detectedURL = extractFirstURL(from: text)
    }
```

`of:`에 `text`를 넣었는데, 클로저가 받는 `oldValue`와 `newValue`는 무엇인가? 그리고 본문에서 둘 다 쓰지 않는데 괜찮은가?

## 공부할 내용

### 결론 먼저

- **`oldValue`는 바뀌기 전 값, `newValue`는 바뀐 후 값**이다. 둘 다 `of:`에 넘긴 `text`의 값이다.
- **둘 다 안 써도 된다.** 다만 지금 코드는 **파라미터를 선언해 놓고 쓰지 않는 어정쩡한 상태**다.
- `onChange`에는 **두 가지 형태**가 있다. 파라미터가 없는 것과 두 개인 것. 하나만 받는 형태는 없다.
- 지금 코드는 파라미터가 필요 없으므로 **파라미터 없는 형태로 쓰는 편이 낫다.**

### 두 가지 형태가 있다

현재 SDK에는 `onChange`가 두 개 있다. 이름은 같고 클로저 모양이 다르다.

**① 파라미터를 받지 않는 형태**

```swift
nonisolated func onChange<V>(
    of value: V,
    initial: Bool = false,
    _ action: @escaping () -> Void
) -> some View where V : Equatable
```

```swift
.onChange(of: playState) {
    model.playStateDidChange(state: playState)
}
```

**② 이전 값과 새 값을 받는 형태**

```swift
nonisolated func onChange<V>(
    of value: V,
    initial: Bool = false,
    _ action: @escaping (V, V) -> Void
) -> some View where V : Equatable
```

> The old and new observed values are passed into the closure.

```swift
.onChange(of: playState) { oldState, newState in
    model.playStateDidChange(from: oldState, to: newState)
}
```

**핵심은 클로저의 파라미터 개수가 어느 형태를 쓸지 결정한다는 점이다.** 예제가 `{ oldValue, newValue in ... }`으로 두 개를 썼으니 ②가 선택됐다.

이름은 아무거나 붙일 수 있다. `oldValue`/`newValue`는 관례일 뿐이고, Apple 예제는 `oldState`/`newState`를 쓴다. 위치가 의미를 정한다 — **첫 번째가 이전 값, 두 번째가 새 값**이다.

### `of:`에 넣은 값과 파라미터의 관계

`of:`에 넘긴 것은 **감시할 대상**이고, 클로저 파라미터는 **그 대상의 값**이다.

```swift
.onChange(of: text) { oldValue, newValue in
//            ↑           ↑          ↑
//         감시 대상   바뀌기 전 text  바뀐 후 text
}
```

사용자가 `"hello"`를 입력한 뒤 `"hello!"`가 되면 이렇게 들어온다.

```text
oldValue = "hello"
newValue = "hello!"
```

이때 **`newValue`와 `text`는 같은 값**이다. 클로저가 불릴 시점에는 `text`가 이미 새 값으로 갱신돼 있기 때문이다. Apple 문서가 이를 명시한다.

> When the value changes, the new version of the closure will be called, so any captured values will have their values from the time that the observed value has its new value.

그래서 예제의 다음 두 줄은 완전히 같은 동작이다.

```swift
detectedURL = extractFirstURL(from: text)        // 현재 코드
detectedURL = extractFirstURL(from: newValue)    // 동일한 결과
```

`oldValue`만이 클로저 밖에서 얻을 수 없는 정보다. **이전 값이 필요 없다면 ② 형태를 쓸 이유가 없다.**

### 그래서 이 코드는 어떻게 쓰는 게 맞나

지금은 파라미터 두 개를 선언해 놓고 하나도 쓰지 않는다. 정리하는 방법이 세 가지다.

```swift
// ① 권장 — 파라미터 없는 형태
.onChange(of: text) {
    detectedURL = extractFirstURL(from: text)
}

// ② newValue를 명시적으로 쓴다
.onChange(of: text) { _, newValue in
    detectedURL = extractFirstURL(from: newValue)
}

// ③ 현재 코드 — 선언만 하고 안 씀
.onChange(of: text) { oldValue, newValue in
    detectedURL = extractFirstURL(from: text)
}
```

①이 가장 깔끔하다. 이전 값이 필요 없다는 의도가 시그니처에 드러난다. ②도 좋다. 안 쓰는 파라미터를 `_`로 명시하면 "일부러 무시한다"는 뜻이 된다.

③은 컴파일은 되지만 읽는 사람이 "이 값들을 어디서 쓰나" 하고 찾게 만든다. 이름 붙인 파라미터를 쓰지 않는 것은 코드 냄새다.

### `initial` 파라미터

두 형태 모두 `initial: Bool = false`를 갖는다. 기본값이 `false`이므로 **뷰가 처음 나타날 때는 실행되지 않고, 값이 바뀔 때만** 실행된다.

`true`로 주면 등장 시점에도 한 번 실행된다.

```swift
.onChange(of: text, initial: true) {
    detectedURL = extractFirstURL(from: text)
}
```

예제에서는 초기 `text`가 `""`라 URL이 있을 리 없으니 의미가 없다. 하지만 저장된 값을 복원해 시작하는 화면이라면 `initial: true`가 `onAppear`를 대체할 수 있다.

### 언제 실행되는가 — `Equatable` 제약

시그니처의 `where V : Equatable`이 중요하다. **값이 실제로 달라졌을 때만** 클로저가 불린다. 같은 값을 다시 대입해도 실행되지 않는다.

[PreferenceKey의 `onPreferenceChange`](./preference-key-and-onpreferencechange.md)가 같은 제약을 갖는 것과 같은 이유다.

### 주의점 — 무거운 작업을 넣지 않는다

> The system may call the action closure on the main actor, so avoid long-running tasks in the closure. If you need to perform such tasks, detach an asynchronous background task.

```swift
.onChange(of: scenePhase) { newScenePhase in
    if newScenePhase == .background {
        Task.detached(priority: .background) {
            // ...
        }
    }
}
```

예제의 `extractFirstURL`은 **타이핑할 때마다** 불린다. `NSDataDetector`를 매번 새로 만들고 전체 텍스트를 다시 훑는 구조라, 긴 글에서는 입력이 버벅일 수 있다. 개선 방향은 [NSDataDetector 문서](./nsdatadetector-and-url-detection.md)에 정리했다.

### 구형 API와의 차이

iOS 17 이전에는 이런 형태였다.

```swift
nonisolated func onChange<V>(of value: V, perform action: @escaping (V) -> Void) -> some View
```

```swift
.onChange(of: scenePhase) { newScenePhase in
    if newScenePhase == .background {
        cache.empty()
    }
}
```

**파라미터가 하나였고 그것이 새 값**이었다. 지금은 deprecated다. 오래된 예제 코드에서 `{ newValue in ... }` 형태를 보면 이 구형 API다.

이 변화 때문에 헷갈리기 쉽다. 정리하면 이렇다.

| 버전 | 파라미터 | 의미 |
| --- | --- | --- |
| 구형 (deprecated) | 1개 | 새 값 |
| 현행 ① | 0개 | — |
| 현행 ② | 2개 | (이전 값, 새 값) |

**파라미터 1개짜리 현행 API는 없다.** 새 값만 쓰고 싶다면 `{ _, newValue in }`으로 첫 번째를 버려야 한다.

### `oldValue`가 실제로 필요한 경우

이전 값이 있어야만 되는 일들이 있다.

```swift
// 증가인지 감소인지 판단
.onChange(of: score) { oldScore, newScore in
    if newScore > oldScore { playSound(.levelUp) }
}

// 변화량 계산
.onChange(of: offset) { oldOffset, newOffset in
    velocity = newOffset - oldOffset
}

// 특정 상태에서 특정 상태로의 전이만 처리
.onChange(of: phase) { oldPhase, newPhase in
    if oldPhase == .loading && newPhase == .ready { startAnimation() }
}

// 이전 값을 되돌리기 위해 보관
.onChange(of: selection) { oldSelection, _ in
    undoStack.append(oldSelection)
}
```

이런 경우가 아니라면 ① 형태가 맞다.

## 학습 체크리스트

- [ ] `oldValue`, `newValue`를 `print`로 찍어 타이핑할 때 어떤 값이 오는지 확인한다.
- [ ] `newValue`와 `text`가 같은 값인지 `print`로 비교한다.
- [ ] 클로저를 `{ }`로 바꿔 파라미터 없는 형태로도 컴파일되는지 확인한다.
- [ ] `{ _, newValue in }`으로 바꿔 첫 파라미터를 명시적으로 무시해 본다.
- [ ] 파라미터를 하나만 쓰는 `{ newValue in }`을 시도해 어떤 에러가 나는지 본다.
- [ ] `initial: true`를 주고 뷰가 나타날 때 실행되는지 확인한다.
- [ ] 같은 값을 다시 대입해 클로저가 불리지 않는 것을 확인한다 (`Equatable`).
- [ ] `oldValue`가 꼭 필요한 예(증감 판단 등)를 하나 직접 만들어 본다.
- [ ] 긴 텍스트를 붙여넣고 타이핑할 때 입력이 느려지는지 체감한다.
- [ ] `onChange`와 `onAppear`의 역할 차이를 `initial` 관점에서 설명한다.

## 공식 참고 자료

- [Apple: view.onChange(of:initial:_:) — 파라미터 없는 형태](https://developer.apple.com/documentation/swiftui/view/onchange(of:initial:_:))
- [Apple: view.onChange(of:initial:_:) — 이전/새 값을 받는 형태](https://developer.apple.com/documentation/swiftui/view/onchange(of:initial:_:)-4psgg)
- [Apple: view.onChange(of:perform:) — 구형 API](https://developer.apple.com/documentation/swiftui/view/onchange(of:perform:))
- [Apple: TextEditor](https://developer.apple.com/documentation/swiftui/texteditor)
- [Apple: View](https://developer.apple.com/documentation/swiftui/view)
- [Swift 공식 문서: Closures](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/closures/)
