//
//  CrashParser.swift
//  ETSymbolicationBuilder
//
//  Created by Itay Brenner on 5/7/23.
//

import ETSymbolicationConstants
import Foundation
import RegexBuilder

private enum CrashResult {
  case nothing
  case symbol(UInt64, Substring)
  case parsingDone
}

struct CrashParser {
  static func parse(_ crashes: [String], library: String, linkerAddress: UInt64) throws
    -> ParseResult
  {
    var symbolsMap: [UInt64: String] = [:]
    var versionUsed: String? = nil

    var counter = 0
    let total = crashes.count
    for crash in crashes {
      print("Parsing \(counter+1)/\(total)")

      guard let streamReader = StreamReader(path: crash) else {
        fatalError("Failed to open the file \(crash).")
      }
      defer {
        streamReader.close()
      }

      var version: String? = nil
      // Check Crash Report OS version
      while let line = streamReader.nextLine() {
        let regex = /OS Version:( )+(iPhone OS|iOS) (\d{2})\.(\d)(.\d)? \((?<version>[\da-zA-Z]+)\)/
        if let match = line.firstMatch(of: regex) {
          version = String(describing: match.version)
          break
        }
      }
      guard let versionFound = version else {
        fatalError("Could not find OS version in \(crash).")
      }
      guard versionUsed == nil || versionUsed == versionFound else {
        fatalError("Multiple versions used for crashes '\(versionUsed!)' and '\(versionFound)'")
      }
      versionUsed = versionFound

      var tmpCrashSymbols: [UInt64: Substring] = [:]

      // Read crash report symbols
      whileLoop: while let line = streamReader.nextLine() {
        switch parseCrashForSymbols(line, library) {
        case .parsingDone:
          break whileLoop  // Stop while
        case .symbol(let address, let symbol):
          tmpCrashSymbols[address] = symbol
        case .nothing:
          break
        }
      }

      var loadAddress: UInt64? = nil
      while let line = streamReader.nextLine() {
        if let address = parseCrashForLoadAddress(line, library) {
          loadAddress = address
          break
        }
      }

      guard let loadAddress = loadAddress else {
        fatalError("Could not find \(library) load address in \(crash).")
      }
      let slide = loadAddress - linkerAddress

      for (address, symbol) in tmpCrashSymbols {
        let (fixedAddress, fixedSymbol) = fixSymbols(address, symbol, slide)
        symbolsMap[fixedAddress] = fixedSymbol
      }

      counter += 1
    }

    return ParseResult(symbols: symbolsMap, version: versionUsed!)
  }

  static let symbolRegex =
    /\d+\s+(?<library>[a-zA-Z0-9]+)\s+\t?0x(?<address>[a-fA-F0-9]{16})\s+(?<method>.+)/
  static private func parseCrashForSymbols(_ line: String, _ library: String) -> CrashResult {
    if let match = line.firstMatch(of: symbolRegex),
      match.library == library,
      let addressAsInt = UInt64(match.address, radix: 16)
    {
      return .symbol(addressAsInt, match.method)
    }

    if line == "Binary Images:" {
      return .parsingDone
    }

    return .nothing
  }

  static let loadRegex =
    /\s+0x(?<memoryAddress>[a-fA-F0-9]{9})\s-\s+0x[a-fA-F0-9]{9}\s(?<library>[a-zA-Z0-9]+)/
  static private func parseCrashForLoadAddress(_ line: String, _ library: String) -> UInt64? {
    if let match = line.firstMatch(of: loadRegex),
      match.library == library
    {
      return UInt64(match.memoryAddress, radix: 16)
    }
    return nil
  }

  static let plusRegex = /\ \+ (?<symbol_length>\d+)/
  static private func fixSymbols(_ address: UInt64, _ symbol: Substring, _ slide: UInt64) -> (
    UInt64, String
  ) {
    var fixedAddress = address - slide
    var fixedSymbol = symbol

    // Symbols fil have formar NEXT_SYMBOL_ADDR: symbol_name + symbol_length
    if let match = fixedSymbol.firstMatch(of: plusRegex) {
      fixedAddress -= UInt64(match.symbol_length) ?? 0

      fixedSymbol.replaceSubrange(match.range, with: "")
    }

    return (fixedAddress, String(fixedSymbol))
  }
}
