// Copyright (c) 1868 Charles Babbage
// Modernized by Robert "r0ml" Lefkowitz <r0ml@liberally.net> in 2026

import Darwin
import SystemPackage

public protocol Stdinable : Sendable {}
extension String : Stdinable {}
extension Substring : Stdinable {}
extension [UInt8] : Stdinable {}
extension FileDescriptor : Stdinable {}
extension AsyncStream : Stdinable {}
extension FilePath : Stdinable {}

public actor ShellProcess {

  public struct ProcessOutput : Sendable {
    public let code : Int32
    public let data : [UInt8]
    public let error : String

    public var string : String { String(decoding: data, as: UTF8.self) }
  }

/*
  public struct Output: Sendable {
        public let terminationStatus: Int32
        public let stdout: [UInt8]
        public let stderr: String
    }
*/

    public struct Options: Sendable {
        public var environment: [String: String]? = nil
        public var currentDirectory: FilePath? = nil

        public init(environment: [String: String]? = nil, currentDirectory: FilePath? = nil) {
            self.environment = environment
            self.currentDirectory = currentDirectory
        }
    }

    public init() {}


/*
  public enum StandardInput: Sendable {
      case inherit
      case string(String)
      case bytes([UInt8])
      case fileDescriptor(FileDescriptor)
      case filePath(FilePath)
      case byteStream(AsyncStream<[UInt8]>)
  }
*/
  
    /// - Parameters:
    ///   - stdin: If non-nil, bytes are written to the child process stdin and then stdin is closed.
  public func run(
        _ executablePath: String,
        withStdin: (any Stdinable)? = nil,
        args arguments: [any Arguable] = [],
        env : [String : String] = [:],
        cd : FilePath? = nil
//        options: Options = .init()
    ) async throws -> ProcessOutput {
        // Pipes for stdout/stderr (always captured)
        let (stdoutR, stdoutW) = try FileDescriptor.pipe()
        let (stderrR, stderrW) = try FileDescriptor.pipe()

        // Optional stdin pipe

/*
        var stdinR: FileDescriptor? = nil
        var stdinW: FileDescriptor? = nil
        if stdin != nil {
            stdinR = r
            stdinW = w
        }
*/

        // posix_spawn file actions are optional-opaque on Darwin in Swift
        var actions: posix_spawn_file_actions_t? = nil
        let irc = posix_spawn_file_actions_init(&actions)
        if irc != 0 { throw POSIXSpawnError(irc, "posix_spawn_file_actions_init") }
        defer { posix_spawn_file_actions_destroy(&actions) }


      var stdinWriteFDForParent: FileDescriptor? = nil
      var openedStdinFDToCloseInParent: FileDescriptor? = nil

      switch withStdin {

        case is FilePath:
          let fp = withStdin as! FilePath
          let fd = try FileDescriptor.open(fp, .readOnly)
          openedStdinFDToCloseInParent = fd
          try addDup2AndClose(&actions, from: fd.rawValue, to: STDIN_FILENO, closeSourceInChild: false)
        case is FileDescriptor:
          let fd = withStdin as! FileDescriptor
          try addDup2AndClose(&actions, from: fd.rawValue, to: STDIN_FILENO, closeSourceInChild: false)
        case is Substring, is String, is [UInt8], is AsyncStream<[UInt8]>:
          let (r, w) = try FileDescriptor.pipe()
        // Wire child's stdio
          try addDup2AndClose(&actions, from: r.rawValue, to: STDIN_FILENO,  closeSourceInChild: true)
          try r.close()
          stdinWriteFDForParent = w
        default:
          break
        }

      try addDup2AndClose(&actions, from: stdoutW.rawValue, to: STDOUT_FILENO, closeSourceInChild: true)
      try addDup2AndClose(&actions, from: stderrW.rawValue, to: STDERR_FILENO, closeSourceInChild: true)

        // Optional cwd (Darwin extension)
      if let cwd = cd {
            let rc = cwd.withPlatformString { posix_spawn_file_actions_addchdir_np(&actions, $0) }
            if rc != 0 { throw POSIXSpawnError(rc, "posix_spawn_file_actions_addchdir_np") }
        }

        // Spawn
      let argvStrings = [executablePath] + arguments.map { $0.asStringArgument() }

      let envpStrings: [String]? = env.map { "\($0.key)=\($0.value)" }

        var pid: pid_t = 0
        let spawnRC: Int32 = try withCStringArray(argvStrings) { argv in
            try withUnsafePointer(to: actions) { actionsPtr in
                if let envpStrings {
                    return try withCStringArray(envpStrings) { envp in
                        posix_spawn(&pid, executablePath, actionsPtr, nil, argv, envp)
                    }
                } else {
                    return posix_spawn(&pid, executablePath, actionsPtr, nil, argv, environ)
                }
            }
        }
        if spawnRC != 0 { throw POSIXSpawnError(spawnRC, "posix_spawn") }

        // Parent side: close pipe ends we must not keep open.
        // - For stdout/stderr: close the write ends in the parent (child owns those).
        try stdoutW.close()
        try stderrW.close()

      // Parent closes any stdin file FD it opened (child has its own dup2’d copy).
      if let fd = openedStdinFDToCloseInParent { try? fd.close() }


      async let stdinDone: Void = {
          guard let w = stdinWriteFDForParent else { return }
          defer { try? w.close() }

        switch withStdin {
          case is String:
            let s = withStdin as! String
            try await w.writeAllBytes(Array(s.utf8))
          case is Substring:
            let s = String(withStdin as! Substring)
            try await w.writeAllBytes(Array(s.utf8))
          case is [UInt8]:
            let b = withStdin as! [UInt8]
            try await w.writeAllBytes(b)
          case is AsyncStream<[UInt8]>:
            let stream = withStdin as! AsyncStream<[UInt8]>
            for await chunk in stream {
              if Task.isCancelled { throw CancellationError() }
              try await w.writeAllBytes(chunk)
            }
          default: break
        }
      }()


        // Concurrently:
        // - drain stdout/stderr
        // - wait for exit
        // - (optionally) write stdin then close it to deliver EOF
        async let outBytes: [UInt8] = stdoutR.readAllBytes()
        async let errBytes: [UInt8] = stderrR.readAllBytes()
        async let status: Int32 = Self.waitForExit(pid: pid)


        let (stdout, stderrRaw, terminationStatus, _) = try await (outBytes, errBytes, status, stdinDone)

        // Close read ends after drain
        try? stdoutR.close()
        try? stderrR.close()

        let stderr = String(decoding: stderrRaw, as: UTF8.self)
        return ProcessOutput(code: terminationStatus, data: stdout, error: stderr)
    }

    // MARK: - Helpers




    private static func waitForExit(pid: pid_t) async throws -> Int32 {
        try await Task.detached {
            var status: Int32 = 0
            while true {
                let w = Darwin.waitpid(pid, &status, 0)
                if w == -1 {
                    if errno == EINTR { continue }
                    throw POSIXSpawnError(errno, "waitpid")
                }
                break
            }

            if wIfExited(status) { return wExitStatus(status) }
            if wIfSignaled(status) { return 128 + wTermSig(status) }
            return status
        }.value
    }
}

// MARK: - posix_spawn file actions wiring (Darwin Swift overlay)

  private func addDup2AndClose(
      _ actions: inout posix_spawn_file_actions_t?,
      from: Int32,
      to: Int32,
      closeSourceInChild: Bool
  ) throws {
      let rc = posix_spawn_file_actions_adddup2(&actions, from, to)
      if rc != 0 { throw POSIXSpawnError(rc, "posix_spawn_file_actions_adddup2") }

      if closeSourceInChild {
          let rc2 = posix_spawn_file_actions_addclose(&actions, from)
          if rc2 != 0 { throw POSIXSpawnError(rc2, "posix_spawn_file_actions_addclose") }
      }
  }

// MARK: - wait status helpers (macros not reliably imported to Swift)

@inline(__always) private func wIfExited(_ s: Int32) -> Bool { (s & 0x7f) == 0 }
@inline(__always) private func wExitStatus(_ s: Int32) -> Int32 { (s >> 8) & 0xff }
@inline(__always) private func wIfSignaled(_ s: Int32) -> Bool { ((s & 0x7f) != 0) && ((s & 0x7f) != 0x7f) }
@inline(__always) private func wTermSig(_ s: Int32) -> Int32 { s & 0x7f }

// MARK: - Error + CString helpers (no Foundation)

public struct POSIXSpawnError: Error, CustomStringConvertible, Sendable {
    public let code: Int32
    public let function: String

    public init(_ code: Int32, _ function: String) {
        self.code = code
        self.function = function
    }

    public var description: String {
        let msg = String(cString: strerror(code))
        return "\(function) failed: \(code) (\(msg))"
    }
}

private func withCStringArray<R>(
    _ strings: [String],
    _ body: ([UnsafeMutablePointer<CChar>?]) throws -> R
) throws -> R {
    var cStrings: [UnsafeMutablePointer<CChar>?] = []
    cStrings.reserveCapacity(strings.count + 1)

    for s in strings {
        cStrings.append(strdup(s))
    }
    cStrings.append(nil)

    defer {
        for p in cStrings where p != nil { free(p) }
    }

    return try body(cStrings)
}


/* esample suage:

 let runner = AsyncSubprocess()

 let input = Array("hello\n".utf8)
 let out = try await runner.run("/usr/bin/wc", ["-c"], stdin: input)

 print(out.terminationStatus) // 0
 print(String(decoding: out.stdout, as: UTF8.self)) // "6\n"
 print(out.stderr) // ""

 */
