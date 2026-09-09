//
//  ContentView.swift
//  chapter-88
//
//  Created by 강준현 on 9/9/26.
//

import SwiftUI

struct ContentView: View {
    @State var networkManager = NetworkManager()

    var body: some View {
        NavigationStack {
            List(networkManager.posts) { post in
                NavigationLink {
                    DetailView(post: post)
                } label: {
                    HStack {
                        Text(post.title)
                            .font(.headline)
                        Spacer()
                        Text(String(post.points))
                            .font(.subheadline)
                    }
                }
            }
            .task {
                await networkManager.fetchPosts()
            }
            .navigationTitle("HackerNews")
        }
    }
}

#Preview {
    ContentView()
}
