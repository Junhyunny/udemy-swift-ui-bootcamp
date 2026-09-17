//
//  URL+Extensions.swift
//  chapter-80
//
//  Created by 강준현 on 9/9/26.
//

import Foundation

// TODO: [todos/024-swift-file-naming-conventions.md](../../../todos/024-swift-file-naming-conventions.md)
extension URL {
    func setQueries(_ queries: [String: String]) -> URL? {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: true)
        components?.queryItems = queries.map { URLQueryItem(name: $0.key, value: $0.value) }
        // TODO: [todos/119-urlcomponents-and-url-building.md](../../../todos/119-urlcomponents-and-url-building.md)
        return components?.url
    }
}
