// Copyright (c) 1868 Charles Babbage
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2026

import CMigration
import SystemPackage
import Darwin
import MachO

extension ShellTest {


  public func fileContents(_ name : String) async throws -> String {
    return try await ShellProcess.fileContents(suiteBundle, name)
  }

  public func inFile(_ name : String) throws -> FilePath {
    return try ShellProcess.inFile(suiteBundle, name)
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

  public func tmpfile(_ s : String, _ data : [UInt8]? = nil) async throws -> FilePath {
    let k = Environment["TMPDIR"] ?? "/tmp" // URL(string: s, relativeTo: FileManager.default.temporaryDirectory)!
    let j = FilePath("\(k)/\(s)")
//    try FileManager.default.createDirectory(at: j.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
//    try? FileManager.default.removeItem(at: j)
    if let data {
      let h = try FileDescriptor.open(j, .writeOnly, options: .create)
      try await h.writeAllBytes(data)
    }
    return j
  }

  public func tmpfile(_ s : String, _ data : String) async throws -> FilePath {
    return try await tmpfile(s, Array(data.utf8))
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


extension ShellProcess {
  /// try fileContents. Opens a file in the current bundle and return as data
  /// - Parameters:
  ///   - name: fileName
  /// - Returns: Data of the contents of the file on nil if not found
  static public func fileContents(_ suiteBundle: String, _ name: String) async throws -> String {
    let url = try geturl(suiteBundle, name)
    let data = try await url.readAllBytes() //  try Data(contentsOf: url)
    let res = String(decoding: data, as: UTF8.self)
    return res
  }

  static public func fileData(_ suiteBundle: String, _ name: String) async throws -> [UInt8] {
  let url = try geturl(suiteBundle, name)
    let data = try await url.readAllBytes() // try Data(contentsOf: url)
  return data
}

  // returns the full name of a test resource file
 static public func inFile(_ suiteBundle : String, _ name : String) throws -> FilePath {
    return try geturl(suiteBundle, name)
  }
  

  static public func geturl(_ suiteBundle : String, _ name : String? = nil) throws -> FilePath {
     var url : FilePath?
     if let _ = Environment["XCTestSessionIdentifier"] {
       let ru = try executableDirectory() // Bundle(for: ShellProcess.self).resourceURL
       if let name {
         url =  FilePath(ru.string + "/" + name ) //   URL(fileURLWithPath: name, relativeTo: ru)
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


extension FilePath {
  /// Read all bytes from a filesystem path.
  /// Fast path: mmap for regular files.
  /// Fallback: async streaming (works for everything open/read supports).
  public func readAllBytes() async throws -> [UInt8] {
    // Try mmap first. If it fails for any reason, fallback.
    if let mm = try? mmapRegularFile() {
      return mm
    }

    // Fallback: open + async streaming read.
    let fd = try FileDescriptor.open(self, .readOnly)
    defer { try? fd.close() }
    return try await fd.readAllBytes()
  }

    // MARK: - mmap fast-path (regular files only)

    /// Returns bytes via mmap if `path` is a regular file; otherwise throws.
    /// This copies once into `[UInt8]` (still typically faster than read loop for large regular files).
    private func mmapRegularFile() throws -> [UInt8] {
        try self.withPlatformString { cPath in
            let fd = Darwin.open(cPath, O_RDONLY)
            if fd < 0 { throw POSIXIOError("open") }
            defer { _ = Darwin.close(fd) }

            var st = stat()
            if fstat(fd, &st) != 0 { throw POSIXIOError("fstat") }

            // Only try mmap for regular files. Pipes/sockets/devices will fail or be meaningless.
            if (st.st_mode & S_IFMT) != S_IFREG {
                throw POSIXIOError("mmap (not a regular file)", EINVAL)
            }

            if st.st_size == 0 { return [] }

            let length = Int(st.st_size)
            let mapped = mmap(nil, length, PROT_READ, MAP_PRIVATE, fd, 0)
            if mapped == MAP_FAILED { throw POSIXIOError("mmap") }
            defer { _ = munmap(mapped, length) }

          let ptr = mapped!.assumingMemoryBound(to: UInt8.self)
            return Array(UnsafeBufferPointer(start: ptr, count: length))
        }
    }
}

extension FileDescriptor {
  /// Read all bytes from an already-open FD (files/pipes/sockets).
  /// This is always streaming (mmap doesn’t apply).
  public func readAllBytes() async throws -> [UInt8] {
    try await Task.detached(priority: nil) {
      var out: [UInt8] = []
      out.reserveCapacity(8192)

      var buf = [UInt8](repeating: 0, count: 64 * 1024)

      while true {
        // Optional cancellation check (won't interrupt a blocked read in progress,
        // but will stop promptly between reads).
        if Task.isCancelled { throw CancellationError() }

        let n: Int
        do {
          n = try buf.withUnsafeMutableBytes { rawBuf in
            try self.read(into: rawBuf)
          }
        } catch let e as Errno {
          if e == .interrupted { continue }   // EINTR
          throw e
        }

        if n == 0 { break } // EOF
        out.append(contentsOf: buf[0..<n])
      }

      return out
    }.value
  }

  public func writeAllBytes(_ bytes: [UInt8]) async throws {
      try await Task.detached {
          var written = 0
          while written < bytes.count {
              let n: Int
              do {
                  n = try bytes.withUnsafeBytes { rawBuf in
                      let base = rawBuf.bindMemory(to: UInt8.self).baseAddress!
                      let ptr = base.advanced(by: written)
                      let remaining = bytes.count - written
                      return try write(UnsafeRawBufferPointer(start: ptr, count: remaining))
                  }
              } catch let e as Errno {
                  if e == .interrupted { continue }
                  throw e
              }
              if n == 0 {
                  // Shouldn't happen for a pipe write unless something is very wrong.
                  throw POSIXSpawnError(EPIPE, "write")
              }
              written += n
          }
      }.value
  }


}

public struct POSIXIOError: Error, CustomStringConvertible, Sendable {
    public let errnoCode: Int32
    public let operation: String

    public init(_ operation: String, _ errnoCode: Int32 = Darwin.errno) {
        self.operation = operation
        self.errnoCode = errnoCode
    }

    public var description: String {
        "\(operation) failed: \(errnoCode) (\(String(cString: strerror(errnoCode))))"
    }
}
