// Copyright (c) 1868 Charles Babbage
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2026

import CMigration
import SystemPackage
import Darwin
import MachO

extension ShellTest {


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
      // FIXME: should there be a FileDescriptor.create -- because options: .create requires permissions
      let h = try FileDescriptor.open(j, .writeOnly, options: .create, permissions: FilePermissions(rawValue: 0o0600))
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
  public func fileContents(_ name: String) throws -> String {
    let url = try geturl(name)
    let data = try url.readAllBytes() //  try Data(contentsOf: url)
    let res = String(decoding: data, as: UTF8.self)
    return res
  }

  // returns the full name of a test resource file
  public func inFile(_ name : String) throws -> FilePath {
    return try geturl(name)
  }
  

  public func geturl(_ name : String? = nil) throws -> FilePath {
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
       let k = testBundleOrExecutablePath()
       let kk = FilePath(k)
       url = kk.removingLastComponent().appending("\(suiteBundle).bundle").appending("Resources")

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


/// Returns the path to the `.xctest` bundle if present; otherwise returns the executable image path.
public func testBundleOrExecutablePath() -> String {
    // Ask dyld where this function lives
    var info = Dl_info()
    let ok = dladdr(unsafeBitCast(testBundleOrExecutablePath as @convention(c) () -> String,
                                  to: UnsafeRawPointer.self),
                    &info)
    guard ok != 0, let fname = info.dli_fname else {
        fatalError("dladdr failed")
    }

    let imagePath = String(cString: fname)

    // If we're inside ".../*.xctest/..." trim back to the bundle root.
    if let r = imagePath.range(of: ".xctest/") {
        let prefix = imagePath[..<r.upperBound]   // includes ".xctest/"
        // drop trailing "/" so it’s a clean bundle path
        return prefix.hasSuffix("/") ? String(prefix.dropLast()) : String(prefix)
    }

    // Otherwise just return the image path (common on Linux, or some runners)
    return imagePath
}


public func packageRoot(from startFile: StaticString = #filePath) -> String {
    var path = String(describing: startFile)

    while path != "/" {
        let candidate = path + "/Package.swift"
        if access(candidate, F_OK) == 0 { return path }

        // strip one path component (POSIX, no Foundation)
        if let slash = path.lastIndex(of: "/") {
            path = String(path[..<slash])
            if path.isEmpty { path = "/" }
        } else {
            break
        }
    }
    fatalError("Could not locate Package.swift from \(startFile)")
}

func currentTestProductName() -> String {
    var info = Dl_info()
    let ok = dladdr(
        unsafeBitCast(currentTestProductName as @convention(c) () -> String,
                      to: UnsafeRawPointer.self),
        &info
    )
    guard ok != 0, let fname = info.dli_fname else {
        return "unknown"
    }

    let imagePath = String(cString: fname)

    // If inside a .xctest bundle: ".../FooTests.xctest/Contents/MacOS/FooTests"
    if let r = imagePath.range(of: ".xctest/") {
        let upTo = imagePath[..<r.lowerBound] // ".../FooTests"
        if let slash = upTo.lastIndex(of: "/") {
            return String(upTo[upTo.index(after: slash)...])
        }
    }

    // Fallback: executable/image filename (often the test product)
    if let slash = imagePath.lastIndex(of: "/") {
        return String(imagePath[imagePath.index(after: slash)...])
    }
    return imagePath
}

@inline(__always)
public func currentTestModule(_ fileID: StaticString = #fileID) -> Substring {
    let s = String(describing: fileID)
    return s.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true).first ?? "unknown"
}
