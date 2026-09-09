//
//  NetworkManager.swift
//  chapter-88
//
//  Created by 강준현 on 9/9/26.
//

import Foundation
import Observation

@Observable
final class NetworkManager {
    // TODO: [todos/array-literal-and-initialization.md](../../todos/array-literal-and-initialization.md)
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
            // TODO: [todos/main-actor-and-ios-threading.md](../../todos/main-actor-and-ios-threading.md)
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
