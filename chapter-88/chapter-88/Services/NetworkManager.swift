//
//  NetworkManager.swift
//  chapter-88
//
//  Created by 강준현 on 9/9/26.
//

import Foundation
import Observation

// FIXME: [Architecture] 이름은 Service 인데 실제로는 ViewModel 역할을 하고 있다.
// - 현상: Services/ 에 있고 이름도 NetworkManager 지만, 화면이 그릴 상태(posts)를 보관하고
//         @Observable 로 View 에 바인딩된다. ContentView 는 이 타입을 @State 로 직접 소유한다.
// - 문제: '통신 방법'과 '화면 상태'가 한 타입에 들어가 둘 다 재사용할 수 없다.
//         다른 화면이 같은 API 를 쓰려면 관계없는 posts 까지 딸려온다.
//         View 가 네트워크 계층을 직접 소유하는 형태라 의존 방향도 거꾸로다.
// - 개선: 두 타입으로 나눈다.
//         * protocol PostFetching / struct HackerNewsService : 요청과 디코딩만. 상태 없음.
//         * @Observable PostListViewModel : posts, isLoading, errorMessage 보유.
//           init(service: PostFetching) 으로 주입받는다.
//         ContentView 는 ViewModel 만 알면 되고, 통신 구현은 갈아끼울 수 있게 된다.
@Observable
final class NetworkManager {
    // TODO: [todos/006-array-literal-and-initialization.md](../../../todos/006-array-literal-and-initialization.md)
    var posts = [Post]()

    func fetchPosts() async {
        guard
            let url = URL(
                string: "https://hn.algolia.com/api/v1/search?tags=story"
            )
        else {
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            // TODO: [todos/106-main-actor-and-ios-threading.md](../../../todos/106-main-actor-and-ios-threading.md)
            // FIXME: [Best Practice] 디코딩을 메인 액터 Task 안에서 하면서 에러를 삼키고 있다.
            // - 문제1: Task 클로저가 throwing 이라 try 실패가 do/catch 로 잡히지 않고 그대로 사라진다.
            //          JSON 스키마가 바뀌어도 화면은 빈 리스트만 보여주고 아무도 모른다.
            // - 문제2: 디코딩은 CPU 작업인데 메인 스레드에서 수행해 응답이 크면 UI 가 끊긴다.
            // - 개선: 클래스를 @MainActor 로 선언하고 decode 는 await 밖(백그라운드)에서 끝낸 뒤
            //         결과만 메인에서 대입한다. 실패는 var errorMessage: String? 같은 상태로 노출한다.
            Task { @MainActor in
                let results = try decoder.decode(Results.self, from: data)
                posts = results.hits
                print(posts)
            }
        } catch {
            print(error.localizedDescription)
        }
    }
}
