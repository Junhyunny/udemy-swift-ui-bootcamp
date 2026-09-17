//
//  Cart.swift
//  chapter-69
//
//  Created by 강준현 on 9/9/26.
//

import SwiftUI
import Foundation
// FIXME: [Best Practice] ObservableObject 를 쓰기 위해 Combine 을 import 하고 있다.
// - 개선: iOS 17+ 를 타깃으로 한다면 @Observable 매크로 + @State/@Bindable 조합으로 옮긴다.
//         Combine import 가 필요 없어지고, 변경된 프로퍼티만 추적해 재렌더 범위가 줄어든다.
internal import Combine

class Cart: ObservableObject {
    @Published var courses: [Course] = []
    
    func addCourse(course: Course) {
        courses.append(course)
    }
    
    func deleteCourse(idSet: IndexSet) {
        courses.remove(atOffsets: idSet)
    }
}
