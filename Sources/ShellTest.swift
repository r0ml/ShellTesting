
/*
  The MIT License (MIT)
  Copyright © 2024 Robert (r0ml) Lefkowitz

  Permission is hereby granted, free of charge, to any person obtaining a copy of this software
  and associated documentation files (the “Software”), to deal in the Software without restriction,
  including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
  and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
  subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
  INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
  OR OTHER DEALINGS IN THE SOFTWARE.
 */


@_exported import CMigration
import Synchronization
@_exported import Testing
import System


public protocol ShellTest {
  var cmd : String { get }
  var suiteBundle : String { get }
}




public protocol Matchable {}
extension String : Matchable {}
extension Regex : Matchable {}
extension Substring : Matchable {}
extension [UInt8] : Matchable {}
extension FilePath : Matchable {}


extension ShellTest {

  public func run(withStdin: (any Stdinable)? = nil, status: Int = 0,
                  output: Matchable? = nil, error: Matchable? = nil,
                  args: Arguable..., env: [String:String] = [:], cd: FilePath? = nil, 
                  newProcessGroup: Bool = false,
                  encoding: IEncoding = .utf8,
                  validation: ((DarwinProcess.Output) async throws -> ())? = nil ) async throws {
    try await run(withStdin: withStdin, status: status, output: output, error: error, args: args, env: env, cd: cd, newProcessGroup: newProcessGroup, encoding: encoding, validation: validation)
  }

  public func run(withStdin: (any Stdinable)? = nil, status: Int = 0,
                  output: Matchable? = nil, error: Matchable? = nil,
                  args: [Arguable], env: [String:String] = [:], cd: FilePath? = nil,
                  newProcessGroup: Bool = false,
                  encoding: IEncoding = .utf8,
                  validation: ((DarwinProcess.Output) async throws -> ())? = nil) async throws {

    if let wd = Environment["XCTestBundlePath"] {
      let p = Environment["PATH"] ?? ""
      let np = FilePath(wd).removingLastComponent().string
      try Environment.setenv("PATH", "\(np):\(p)")
    }

    // var envx = env
    // envx["SHELLDEBUGGING"]="1"
    
//    var xenv = env
//    xenv["LC_CTYPE"] = encoding.canonical 

    let po = try await DarwinProcess().run(cmd, withStdin: withStdin, args: args, env: env, cd: cd, newProcessGroup: newProcessGroup, encoding: encoding)
    #expect(po.code == Int32(status), Comment("\(po.error)") )
    if let output {
      switch output {
        case is String:
          let stdout = try po.string(encoded: encoding)
          #expect( stdout == output as? String )
        case is Substring:
          let stdout = try po.string(encoded: encoding)
          #expect( stdout == output as! Substring)
        case is [UInt8]:
          #expect( po.data == Array(output as! [UInt8]))
        case is FilePath:
          let dd = try (output as! FilePath).readAllBytes()
          #expect( po.data == dd )
        case _ where eraseToAnyRegex(output) != nil:
          let jj = try po.string(encoded: encoding)
            let r = eraseToAnyRegex(output)!
            #expect(jj.matches(of: r).count > 0, Comment(rawValue: "\(jj) does not match expected output"))
        default:
          fatalError("not possible")
      }
    }

//    if let output { #expect(j == output) }
    if let error {
        switch error {
          case is String:
            #expect(po.error == error as? String)
          case is Substring:
            #expect(po.error == (error as! Substring))
          case _ where eraseToAnyRegex(error as Any) != nil:
            let jj = po.error
              let r = eraseToAnyRegex(error as Any)!
              #expect(jj.matches(of: r).count > 0, Comment(rawValue: "\(jj) does not match expected error"))
/*
          case is Regex<String>:
            let ee = error as! Regex<String>
            #expect( po.error.matches(of: ee).count > 0, Comment(rawValue: "\(po.error) does not match expected error"))
          case is Regex<Substring>:
            let ee = error as! Regex<Substring>
            #expect( po.error.matches(of: ee).count > 0, Comment(rawValue: "\(po.error) does not match expected error"))
 */
          default: fatalError("not possible")
        }
      }

    if let validation {
      try await validation(po)
    }
  }
}
