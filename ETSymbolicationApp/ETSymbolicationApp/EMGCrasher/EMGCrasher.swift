//
//  EMGCrasher.swift
//  ETSymbolicationApp
//
//  Created by Itay Brenner on 30/6/23.
//

import Foundation

class EMGCrasher {
    var completedThreads = 0
    let lock = NSLock()
    
    func crash(_ lib: Library, _ threadCount: Int, _ offset: Int) -> Bool {
        let functions = get_function_starts(lib.path.cString(using: .utf8))
            
        let indexOffset = offset * Int(MAX_FRAMES) * threadCount
        guard indexOffset < functions.functionsCount else {
            return false
        }
        
        for index in 0..<threadCount {
            let thread = EMGThread()
            thread.startingIndex = index * Int(MAX_FRAMES) + indexOffset
            thread.addresses = functions.functionsPointers!
            thread.completionBlock = { [self] in
                self.lock.lock()
                self.completedThreads += 1
                self.lock.unlock()
            }
            thread.start()
        }
        
        while(completedThreads != threadCount) {
            usleep(100)
        }
        
        fatalError("Crash App (Excpected)")
    }
}
