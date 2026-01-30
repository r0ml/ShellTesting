// Copyright (c) 1868 Charles Babbage
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2026

import CMigration
import SystemPackage
import Darwin
import MachO

extension ShellTest {


  public func fileContents(_ name : String) throws -> String {
    return try fileContents(suiteBundle, name)
  }

  public func inFile(_ name : String) throws -> FilePath {
    return try inFile(suiteBundle, name)
  }


  public func tmpdir(_ s : String) throws -> FilePath {
    let j = Environment["TMPDIR"] ?? "/tmp" // URL(string: s, relativeTo: FileManager.default.temporaryDirectory)!
    let k = "\(j)/\(s)"
    // FIXME: do I need to sort out intermediate directories?
    let a = mkdir(k, 0o0700)
    if a == 0 { return FilePath(k) }
    else {
      throw POSIXErrno(errno)
    }
  }

  public func tmpfile(_ s : String, _ data : [UInt8]? = nil) throws -> FilePath {
    let k = Environment["TMPDIR"] ?? "/tmp" // URL(string: s, relativeTo: FileManager.default.temporaryDirectory)!
    let j = FilePath("\(k)/\(s)")
//    try FileManager.default.createDirectory(at: j.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
//    try? FileManager.default.removeItem(at: j)
    if let data {
      let h = try FileDescriptor.open(j, .writeOnly, options: .create)
      try h.writeAllBytes(data)
    }
    return j
  }

  public func tmpfile(_ s : String, _ data : String) throws -> FilePath {
    return try tmpfile(s, Array(data.utf8))
  }

  public func rm(_ s : FilePath) {
    unlink(s.string)
//    try? FileManager.default.removeItem(at: s)
  }

  public func rm(_ s : [FilePath]) {
    s.forEach { rm($0) }
  }

  public func rm( _ s : FilePath...) {
    rm(s)
  }

}


extension ShellTest {
  /// try fileContents. Opens a file in the current bundle and return as data
  /// - Parameters:
  ///   - name: fileName
  /// - Returns: Data of the contents of the file on nil if not found
  func fileContents(_ suiteBundle: String, _ name: String) throws -> String {
    let url = try geturl(suiteBundle, name)
    let data = try url.readAllBytes() //  try Data(contentsOf: url)
    let res = String(decoding: data, as: UTF8.self)
    return res
  }

  // returns the full name of a test resource file
  func inFile(_ suiteBundle : String, _ name : String) throws -> FilePath {
    return try geturl(suiteBundle, name)
  }
  

  func geturl(_ suiteBundle : String, _ name : String? = nil) throws -> FilePath {
     var url : FilePath?
     if let tbp = Environment["XCTestBundlePath"] {
       let ru = FilePath(tbp).appending("Contents").appending("Resources") 
       if let name {
         url =  ru.appending(name)
       } else {
         url = ru
       }
     } else {
//       let b = Bundle(for: ShellProcess.self)
       // Doens't work without the directory hint!
//       url = b.bundleURL.deletingLastPathComponent().appending(path: "\(suiteBundle).bundle").appending(path: "Resources", directoryHint: .isDirectory)
       url = try executableDirectory().removingLastComponent().appending("\(suiteBundle).bundle").appending("Resources")
       if let name {
         url = url?.appending(name)
       }
     }
     if let url { return url }
     throw FileError.notFound(name ?? "")

   }

}


public enum FileError: Error {
  case notFound(String)
}

/*
public enum StringEncodingError: Error {
    case only(String.Encoding)
}
*/

func executableDirectory() throws -> FilePath {
    let path = try executablePath()
    return path.removingLastComponent()
}

func executablePath() throws -> FilePath {
  var buf = [CChar](repeating: 0, count: Int(Darwin.MAXPATHLEN))
    var size = UInt32(buf.count)
  if MachO._NSGetExecutablePath(&buf, &size) != 0 {
        throw Errno.noMemory
    }
    return FilePath(String(platformString: buf))
}

// ==============================================================


