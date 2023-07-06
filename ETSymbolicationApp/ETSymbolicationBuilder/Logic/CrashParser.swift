//
//  CrashParser.swift
//  ETSymbolicationBuilder
//
//  Created by Itay Brenner on 5/7/23.
//

import Foundation
import RegexBuilder
import ETSymbolicationConstants

private enum CrashResult {
    case nothing
    case symbol(UInt64, Substring)
    case parsingDone
}

struct CrashParser {
    static func parse(_ crashes: [String], library: String, linkerAddress: UInt64) throws -> ParseResult {
        var symbolsMap: [UInt64:String] = [:]
        var versionUsed: String? = nil
        
        var counter = 0
        var total = crashes.count
        for crash in crashes {
            print("Parsing \(counter)/\(total)")
            
            guard let streamReader = StreamReader(path: crash) else {
                fatalError("Failed to open the file \(crash).")
            }
            defer {
                streamReader.close()
            }
            
            var version: String? = nil
            // Check Crash Report OS version
            while let line = streamReader.nextLine() {
                let regex = /OS Version:( )+iPhone OS (\d{2}).(\d).(\d)? \((?<version>[\dA-Z]+)\)/
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
            
            var tmpCrashSymbols: [UInt64:Substring] = [:]
            
            // Read crash report symbols
            whileLoop: while let line = streamReader.nextLine() {
                switch parseCrashForSymbols(line, library) {
                case .parsingDone:
                    break whileLoop // Stop while
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
            let slide = loadAddress - linkerAddress;
            
            for (address, symbol) in tmpCrashSymbols {
                let (fixedAddress, fixedSymbol) = fixSymbols(address, symbol, slide)
                symbolsMap[fixedAddress] = fixedSymbol
            }
            
            counter += 1
        }
        
        return ParseResult(symbols: symbolsMap, version: versionUsed!)
    }
    
    static private func parseCrashForSymbols(_ line: String, _ library: String) -> CrashResult {
        let methodRef = Reference(Substring.self)
        let addressRef = Reference(Substring.self)
        
        let regex = Regex {
            OneOrMore(.digit)
            OneOrMore(.whitespace)
            library
            OneOrMore(.whitespace)
            "\t0x"
            Capture(as: addressRef) {
                Repeat(count: 16) {
                    One(.hexDigit)
                }
            }
            One(.whitespace)
            Capture(as: methodRef) {
                OneOrMore(.any)
            }
        }
        
        if let match = line.firstMatch(of: regex),
           let addressAsInt = UInt64(match[addressRef], radix: 16) {
            return .symbol(addressAsInt, match[methodRef])
        }
        
        if line == "Binary Images:" {
            return .parsingDone
        }
        
        return .nothing
    }
    
    static private func parseCrashForLoadAddress(_ line: String, _ library: String) -> UInt64? {
        let memoryAddress = Reference(Substring.self)
        let loadRegex = Regex {
            OneOrMore(.whitespace)
            "0x"
            Capture(as: memoryAddress) {
                Repeat(count: 9) {
                    One(.hexDigit)
                }
            }
            " -"
            OneOrMore(.whitespace)
            "0x"
            Repeat(count: 9) {
                One(.hexDigit)
            }
            " \(library)"
        }
        
        if let match = line.firstMatch(of: loadRegex) {
            return UInt64(match[memoryAddress], radix: 16)
        }
        return nil
    }
    
    static private func fixSymbols(_ address: UInt64, _ symbol: Substring, _ slide: UInt64) -> (UInt64, String) {
        // Fix addresses and offsets
        let fixedAddress = address - slide - ETSymbolicationConstants.addressOffset
        
        var fixedSymbol = symbol
        
        let plusRegex = /\ \+ (?<address>\d+)/
        if let match = fixedSymbol.firstMatch(of: plusRegex),
           let addressAsInt = UInt64(match.address) {
            
            if addressAsInt == ETSymbolicationConstants.addressOffset {
                fixedSymbol.replaceSubrange(match.range, with: "")
            } else {
                fixedSymbol.replaceSubrange(match.range, with: " + \(addressAsInt - ETSymbolicationConstants.addressOffset)")
            }
        }
        
        return (fixedAddress, String(fixedSymbol))
    }
}
