//
//  Libraries.swift
//  ETSymbolicationApp
//
//  Created by Itay Brenner on 6/7/23.
//

import Foundation

struct Libraries {
    // Add here libraries to symbolicate
    static let list = [
        Library(name: "SwiftUI", path: "/System/Library/Frameworks/SwiftUI.framework/SwiftUI"),
        Library(name: "MetalPerformanceShadersGraph", path: "/System/Library/Frameworks/MetalPerformanceShadersGraph.framework/MetalPerformanceShadersGraph")
    ]
}
