//
//  ResultWriter.swift
//  ETSymbolicationBuilder
//
//  Created by Itay Brenner on 6/7/23.
//

import Foundation

struct ResultWriter {
    static func write(_ path: String, _ library: String, _ result: ParseResult, _ isCSV: Bool) throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: path) {
            fileManager.createFile(atPath: path, contents: nil)
        }
        guard let fileHandle = FileHandle(forWritingAtPath: path) else {
            fatalError("Could not open file handle for output file \(path)")
        }
        
        defer {
            try! fileHandle.close()
        }
        
        let symbols = result.symbols
        let version = result.version
        
        if isCSV {
            writeAsCSV(fileHandle, symbols, version, library)
        } else {
            writeAsTxt(fileHandle, symbols)
        }
    }
    
    private static func writeAsCSV(_ handle: FileHandle, _ symbols: [UInt64: String], _ version: String, _ library: String) {
        let sortedAddresses = symbols.keys.sorted()
        for index in 0..<sortedAddresses.count {
            let address = sortedAddresses[index]
            let nextAddress = index+1 < sortedAddresses.count ? sortedAddresses[index+1] : UInt64.max
            
            let libraryPath = "/System/Library/Frameworks/\(library).framework/\(library)"
            let symbol = formatSymbol(String(symbols[address]!))
            
            if symbol.hasPrefix("0x") {
                // Skip unresolved symbols
                continue
            }
            
            let string = String(format: "\(libraryPath),\"[0x%016llX,0x%016llX)\",\"\(symbol)\",\(version)\n", address, nextAddress)
            let data = string.data(using: .ascii)!
            handle.write(data)
        }
        print("Remember to manually fix last address (0xFFFFFFFFFFFFFFFF) in the CSV")
    }
    
    private static func writeAsTxt(_ handle: FileHandle, _ symbols: [UInt64: String]) {
        let sortedAddresses = symbols.keys.sorted()
        for address in sortedAddresses {
            let string = String(format: "0x%016llX - %@\n", address, String(describing: symbols[address]!))
            let data = string.data(using: .ascii)!
            handle.write(data)
        }
    }
    
    private static func formatSymbol(_ sym: String) -> String {
        let result = sym.replacingOccurrences(of: ":\\d+\\)", with: ")", options: .regularExpression) // static AppDelegate.$main() (in emergeTest) (AppDelegate.swift:10)
            .replacingOccurrences(of: " \\+ \\d+$", with: "", options: .regularExpression) // _dyld_start (in dyld) + 0
            .replacingOccurrences(of: " (<compiler-generated>)$", with: "", options: .regularExpression) // static UIApplicationDelegate.main() (in emergeTest) (<compiler-generated>)
            .replacingOccurrences(of: " \\(\\S+.\\S+\\)$", with: "", options: .regularExpression) // static AppDelegate.$main() (in emergeTest) (AppDelegate.swift)
            .replacingOccurrences(of: " \\(in (\\S| )+\\)", with: "", options: .regularExpression) // static AppDelegate.$main() (in emergeTest)
            .replacingOccurrences(of: "^__\\d+\\+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "^__\\d+\\-", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return result
    }
}
