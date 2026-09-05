//
//  ContentView.swift
//  chapter-18
//
//  Created by 강준현 on 9/5/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        PhotoGalleryApp()
    }
}

struct PhotoGalleryApp: View {
    @State private var selectedIamge: String? = nil
    let images = [
        "photo1",
        "photo2",
        "photo3",
        "photo4",
        "photo5",
    ]
    var body: some View {
        NavigationStack {
            VStack {
                if let selectedIamge {
                    EnlargedPhotoView(imageName: selectedIamge) {
                        self.selectedIamge = nil
                    }
                } else {
                    ScrollView {
                        VStack {
                            // TODO: [todos/foreach-id-and-identity-keypath.md](../../todos/foreach-id-and-identity-keypath.md)
                            ForEach(images, id: \.self) {
                                image in
                                Image(image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 300)
                                    .clipShape(.rect(cornerRadius: 10))
                                    .shadow(radius: 5)
                                    .onTapGesture {
                                        self.selectedIamge = image
                                    }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Photo Gallery")
        }
    }
}

struct EnlargedPhotoView: View {
    let imageName: String
    let onClose: () -> Void
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .padding()
                    .background(.white)
                    .clipShape(.rect(cornerRadius: 10))
                    .shadow(radius: 5)
                Button(action: onClose) {
                    Text("Close")
                        .foregroundStyle(.white)
                        .padding()
                        .background(.red)
                        .clipShape(.rect(cornerRadius: 10))
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
