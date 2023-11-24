//
//  main.swift
//  ETSymbolicationBuilder
//
//  Created by Itay Brenner on 5/7/23.
//

import Foundation
import ArgumentParser

@main
struct ETSymbolicationBuilder: ParsableCommand {
    @Flag(help: "Output as csv format.")
    var csv: Bool = false
    
    @Option(name: .shortAndLong, help: "Folder containing crash reports.")
    var input: String
    
    @Option(name: .shortAndLong, help: "Output folder.")
    var output: String
    
    @Option(name: [.customShort("l"), .long], help: "Library whose symbols you want to build.")
    var libraryName: String
    
    @Option(name: [.customShort("a"), .long], help: "Library linker address. Can be extracted with `otool -l LIBRARY_BINARY | grep LC_SEGMENT -A8`.")
    var libraryLinkerAddress: String
    
    mutating func run() throws {
        guard let linkerAddress = UInt64(libraryLinkerAddress, radix: 16) else {
            fatalError("Invalid linker address, please insert it without 0x prefix (example 1234 for address 0x1234)")
        }
        
        let crashes = try CrashVerifier.getCrashes(at: input)
        
        let outputFileName = csv ? "\(libraryName).csv" : libraryName
        guard let outputFullPath = URL(string: output)?.appending(path: outputFileName).absoluteString else {
            fatalError("Invalid output path")
        }
        
        let parseResult = try CrashParser.parse(crashes,
                                                library: libraryName,
                                                linkerAddress: linkerAddress)
        print("Writing results to: \(outputFullPath)")
        try ResultWriter.write(outputFullPath, libraryName, parseResult, csv)
    }
}
