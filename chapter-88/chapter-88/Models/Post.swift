//
//  Post.swift
//  chapter-88
//
//  Created by 강준현 on 9/9/26.
//

import Foundation

struct Results: Decodable {
    let hits: [Post]
}

struct Post: Decodable, Identifiable {
    // TODO: [todos/computed-property-with-closure-body.md](../../todos/computed-property-with-closure-body.md)
    var id: String { return objectID }
    let objectID: String
    let title: String
    let points: Int
    let url: String
}
