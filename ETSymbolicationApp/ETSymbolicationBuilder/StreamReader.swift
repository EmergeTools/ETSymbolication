//
//  StreamReader.swift
//  ETSymbolicationBuilder
//
//  Created by Itay Brenner on 5/7/23.
//

import Foundation

class StreamReader {
  let encoding: String.Encoding
  let chunkSize: Int

  var fileHandle: FileHandle?
  var buffer: Data
  var delimiterData: Data
  var atEOF: Bool = false

  convenience init?(
    path: String, delimiter: String = "\n", encoding: String.Encoding = .utf8, chunkSize: Int = 4096
  ) {
    guard let url = URL(string: path) else {
      return nil
    }
    self.init(url: url, delimiter: delimiter, encoding: encoding, chunkSize: chunkSize)
  }
  
  init?(
    url: URL, delimiter: String = "\n", encoding: String.Encoding = .utf8, chunkSize: Int = 4096
  ) {
    guard let fileHandle = try? FileHandle(forReadingFrom: url),
      let delimiterData = delimiter.data(using: encoding)
    else {
      return nil
    }

    self.fileHandle = fileHandle
    self.buffer = Data(capacity: chunkSize)
    self.delimiterData = delimiterData
    self.encoding = encoding
    self.chunkSize = chunkSize
  }

  deinit {
    self.close()
  }

  func reset() {
    try? fileHandle?.seek(toOffset: 0)
    buffer = Data(capacity: chunkSize)
  }

  func nextLine() -> String? {
    if atEOF { return nil }

    repeat {
      if let range = buffer.range(of: delimiterData) {
        let line = String(data: buffer.subdata(in: 0..<range.lowerBound), encoding: encoding)
        buffer.removeSubrange(0...range.lowerBound)
        return line
      }

      let tmpData = fileHandle?.readData(ofLength: chunkSize)
      if tmpData == nil || tmpData!.count == 0 {
        atEOF = true

        if buffer.count > 0 {
          let line = String(data: buffer, encoding: encoding)
          buffer.count = 0
          return line
        }

        return nil
      }

      buffer.append(tmpData!)
    } while true
  }

  func close() {
    fileHandle?.closeFile()
    fileHandle = nil
  }
}
