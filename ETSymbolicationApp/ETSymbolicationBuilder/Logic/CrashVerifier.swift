//
//  CrashVerifier.swift
//  ETSymbolicationBuilder
//
//  Created by Itay Brenner on 5/7/23.
//

import Foundation

struct CrashVerifier {
    static func getCrashes(at path: String) throws -> [String] {
        let fileManager = FileManager.default
        
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            fatalError("Path \(path) does not exists")
        }
        guard isDirectory.boolValue else {
            fatalError("Path \(path) does not a directory")
        }
        
        var crashes = try fileManager.contentsOfDirectory(atPath: path)
        crashes = crashes.filter { crash in
            crash.hasSuffix(".crash")
        }
        
        guard crashes.count > 0 else {
            fatalError("Path \(path) does not contain crashes")
        }
        
        return crashes.map { "\(path)/\($0)" }
    }
}
