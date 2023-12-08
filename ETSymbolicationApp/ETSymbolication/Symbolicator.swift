//
//  Symbolicator.swift
//  ETSymbolication
//
//  Created by Itay Brenner on 23/11/23.
//

import Foundation

class Symbolicator {
  let version: String
  private var addressesToSymbols: [String: [UInt64: String]] = [:]
  private var sortedAddresses: [String: [UInt64]] = [:]

  init(version: String) throws {
    self.version = version
    loadAddresses()
  }

  private func loadAddresses() {
    let fileManager = FileManager.default
    let symbolsURL = fileManager.homeDirectoryForCurrentUser.appending(path: "/Symbols/\(version).csv")

    guard let streamReader = StreamReader(url: symbolsURL) else {
      fatalError("Failed to open the file \(symbolsURL.path).")
    }
    defer {
      streamReader.close()
    }
    let regex =
      /\/(?<library>[a-zA-Z0-9]+),"\[0x(?<startAddress>[a-fA-F0-9]{16}),0x[a-fA-F0-9]{16}\)","(?<symbol>.+)",/
    while let line = streamReader.nextLine() {
      if let match = line.firstMatch(of: regex),
        let address = UInt64(match.startAddress, radix: 16)
      {
        let library = String(match.library)
        let symbol = String(match.symbol)
        if addressesToSymbols[library] == nil {
          addressesToSymbols[library] = [:]
        }
        addressesToSymbols[library]![address] = symbol
      }
    }
  }

  func getSymbolNameForAddress(_ library: String, _ address: UInt64) -> String? {
    // Lets make sure addresses are sorted, just in case the CSV had an issue
    var librarySortedAddresses = sortedAddresses[library]
    if librarySortedAddresses == nil {
      librarySortedAddresses = addressesToSymbols[library]!.keys.sorted()
      sortedAddresses[library] = librarySortedAddresses
    }
    let symbol = findLargestLowerItem(librarySortedAddresses!, address)!
    return addressesToSymbols[library]![symbol]
  }

  private func findLargestLowerItem(_ array: [UInt64], _ value: UInt64) -> UInt64? {
    var left = 0
    var right = array.count - 1
    var result: UInt64?

    while left <= right {
      let mid = (left + right) / 2
      let midValue = array[mid]

      if midValue < value {
        result = midValue
        left = mid + 1
      } else {
        right = mid - 1
      }
    }

    return result
  }
}
