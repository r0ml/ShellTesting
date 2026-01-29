// Copyright (c) 1868 Charles Babbage
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2026

import CMigration
import SystemPackage

extension ShellTest {


  public func fileContents(_ name : String) throws -> String {
    return try ShellProcess.fileContents(suiteBundle, name)
  }

  public func inFile(_ name : String) throws -> URL {
    return try ShellProcess.inFile(suiteBundle, name)
  }


  public func tmpdir(_ s : String) throws -> URL {
    let j = URL(string: s, relativeTo: FileManager.default.temporaryDirectory)!
    try FileManager.default.createDirectory(at: j, withIntermediateDirectories: true, attributes: nil)
    return j
  }

  public func tmpfile(_ s : String, _ data : Data? = nil) throws -> URL {
    let j = URL(string: s, relativeTo: FileManager.default.temporaryDirectory)!

    try FileManager.default.createDirectory(at: j.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
    try? FileManager.default.removeItem(at: j)
    if let data { try data.write(to: j) }
    return j
  }

  public func tmpfile(_ s : String, _ data : String) throws -> URL {
    return try tmpfile(s, data.data(using: .utf8))
  }

  public func rm(_ s : URL) {
    try? FileManager.default.removeItem(at: s)
  }

  public func rm(_ s : [URL]) {
    s.forEach { rm($0) }
  }

  public func rm( _ s : URL...) {
    rm(s)
  }

}


extension ShellProcess {
  /// try fileContents. Opens a file in the current bundle and return as data
  /// - Parameters:
  ///   - name: fileName
  /// - Returns: Data of the contents of the file on nil if not found
  static public func fileContents(_ suiteBundle: String, _ name: String) throws -> String {
    let url = try geturl(suiteBundle, name)
    let data = try Data(contentsOf: url)
    guard let res = String(data: data, encoding: .utf8) else {
      throw StringEncodingError.only(.utf8)
    }
    return res
  }

  static public func fileData(_ suiteBundle: String, _ name: String) throws -> Data {
  let url = try geturl(suiteBundle, name)
  let data = try Data(contentsOf: url)
  return data
}

  // returns the full name of a test resource file
 static public func inFile(_ suiteBundle : String, _ name : String) throws -> URL {
    return try geturl(suiteBundle, name)
  }
  

}


