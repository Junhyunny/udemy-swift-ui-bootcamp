//
//  Cart.swift
//  chapter-69
//
//  Created by 강준현 on 9/9/26.
//

import SwiftUI
import Foundation
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
