//
//  DetailView.swift
//  chapter-88
//
//  Created by 강준현 on 9/9/26.
//

import SwiftUI

struct DetailView: View {
    let post: Post

    var body: some View {
        WebView(urlString: post.url)
    }
}

#Preview {
    DetailView(
        post: Post(
            objectID: "objectID",
            title: "title",
            points: 0,
            url: "https://google.com"
        )
    )
}
