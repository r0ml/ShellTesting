
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
import SystemPackage


public protocol ShellTest {
  var cmd : String { get }
  var suiteBundle : String { get }
//  var suiteBundle : String { get }
}




public protocol Matchable {}
extension String : Matchable {}
extension Regex : Matchable {}
extension Substring : Matchable {}
extension [UInt8] : Matchable {}

extension ShellTest {

  public func run(withStdin: (any Stdinable)? = nil, status: Int = 0, output: Matchable? = nil, error: Matchable? = nil, args: Arguable..., env: [String:String] = [:], cd: FilePath? = nil, _ validation : ((ShellProcess.ProcessOutput) async throws -> ())? = nil ) async throws {
    try await run(withStdin: withStdin, status: status, output: output, error: error, args: args, env: env, cd: cd, validation)
  }

  public func run(withStdin: (any Stdinable)? = nil, status: Int = 0, output: Matchable? = nil, error: Matchable? = nil, args: [Arguable], env: [String:String] = [:], cd: FilePath? = nil, _ validation : ((ShellProcess.ProcessOutput) async throws -> ())? = nil) async throws {
    let po = try await ShellProcess().run(cmd, withStdin: withStdin, args: args, env: env, cd: cd)
    // FIXME: why did Comment break?
    #expect(po.code == Int32(status)) // , Comment(rawValue: e ?? ""))
    if let output {
      switch output {
        case is String:
          #expect( po.string == output as? String )
        case is Substring:
          #expect( po.string == output as! Substring)
        case is [UInt8]:
          #expect( po.data == Array(output as! [UInt8]))
/*
        case is Regex<String>:
          let jj = output as! Regex<String>
          #expect( j!.matches(of: jj).count > 0, Comment(rawValue: "\(j!) does not match expected output"))
        case is Regex<Substring>:
          let jj = output as! Regex<Substring>
          #expect( j!.matches(of: jj).count > 0, Comment(rawValue: "\(j!) does not match expected output"))
        case let jj as Regex<AnyRegexOutput>:
          #expect( j!.matches(of: jj).count > 0, Comment(rawValue: "\(j!) does not match expected output"))
        case let jj as Regex<Any>:
          #expect( j!.matches(of: jj).count > 0, Comment(rawValue: "\(j!) does not match expected output"))
 */
        case _ where eraseToAnyRegex(output) != nil:
          let jj = po.string
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
          case is Regex<String>:
            let ee = error as! Regex<String>
            #expect( po.error.matches(of: ee).count > 0, Comment(rawValue: "\(po.error) does not match expected error"))
          case is Regex<Substring>:
            let ee = error as! Regex<Substring>
            #expect( po.error.matches(of: ee).count > 0, Comment(rawValue: "\(po.error) does not match expected error"))
          default: fatalError("not possible")
        }
      }

    if let validation {
      try await validation(po)
    }
  }

  public func geturl(_ name : String? = nil) throws -> FilePath {
    return try ShellProcess.geturl(suiteBundle, name)
  }

}

/*
func numberStream() -> AsyncStream<Int> {
    return AsyncStream { continuation in
        for number in 1...100 {
            continuation.yield(number)
        }
        continuation.finish()
    }
}
*/

