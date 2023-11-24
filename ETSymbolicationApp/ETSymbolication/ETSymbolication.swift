//
//  main.swift
//  ETSymbolication
//
//  Created by Itay Brenner on 23/11/23.
//

import ArgumentParser
import Foundation

enum Constants {
  // SwiftUI linker addresses
  static let linkerAddresses: [String: UInt64] = [
    "20F66": 0x0000_0001_8a8b_f000,  // iOS 16.5 - iPhone 14 Pro
    "21B91": 0x0000_0001_8b9e_c000,  // iOS 17.1.1 - iPhone SE

      // Extracted with otool -l SwiftUI | grep LC_SEGMENT -A8 | grep "segname __TEXT" -A7 | grep vmaddr
      // cmd LC_SEGMENT_64
      // cmdsize 1992
      // segname __TEXT
      // vmaddr 0x000000018a8bf000
  ]
}

@main
struct ETSymbolicator: ParsableCommand {
  @Option(name: .shortAndLong, help: "Path to crash log.")
  var crashLog: String
  
  @Option(name: .shortAndLong, help: "Library to symbolicate.")
  var library: String = "SwiftUI"
  
  func findVersion(_ reader: StreamReader) -> String? {
    while let line = reader.nextLine() {
      let regex = /OS Version:( )+(iPhone OS|iOS) (\d{2})\.(\d)(.\d)? \((?<version>[\da-zA-Z]+)\)/
      if let match = line.firstMatch(of: regex) {
        return String(describing: match.version)
      }
    }
    return nil
  }

  mutating func run() throws {
    let fileManager = FileManager.default

    guard fileManager.fileExists(atPath: crashLog) else {
      fatalError("No crash report found ath path \(crashLog)")
    }

    guard let streamReader = StreamReader(path: crashLog) else {
      fatalError("Failed to open the file \(crashLog).")
    }
    defer {
      streamReader.close()
    }

    guard let version = findVersion(streamReader) else {
      fatalError("Could not find OS version in \(crashLog).")
    }
    
    var loadAddress: UInt64 = 0
    while let line = streamReader.nextLine() {
      let loadRegex = /\s+0x(?<memoryAddress>[a-fA-F0-9]{9})\s-\s+0x[a-fA-F0-9]{9}\s(?<library>[a-zA-Z0-9]+)/
      if let match = line.firstMatch(of: loadRegex),
         match.library == library,
         let addressAsInt = UInt64(match.memoryAddress, radix: 16) {
        loadAddress = addressAsInt
        streamReader.reset() // reset strem to start reading from the first line
        break;
      }
    }
    guard loadAddress != 0 else {
      fatalError("Could not find load address for \(library).")
    }
    guard let linkerAddress = Constants.linkerAddresses[version] else {
      fatalError("Missing linker address for \(library) and version \(version).")
    }
    let slide = loadAddress - linkerAddress
    
    let symbolicator = try Symbolicator(version: version)
    let symbolsRegex = /(?<line>(\d+)\s+(?<library>[a-zA-Z0-9]+)( )+\t?\s*0x(?<address>[\da-f]{0,16})) (?<method>.*)/
    while let line = streamReader.nextLine() {
      if let match = line.firstMatch(of: symbolsRegex),
         match.library == library,
         let address = UInt64(match.address, radix: 16),
         let symbolicateMethod = symbolicator.getSymbolNameForAddress(library, address-slide) {
          print("\(match.line) \(symbolicateMethod)")
      } else {
        print(line)
      }
    }
  }
}
