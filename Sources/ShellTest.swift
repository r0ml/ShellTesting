
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


public protocol ShellTest {
  var cmd : String { get }
  var suiteBundle : String { get }
//  var suiteBundle : String { get }
}

public protocol Stdinable : Sendable {}
extension String : Stdinable {}
extension Data : Stdinable {}
extension FileHandle : Stdinable {}
extension AsyncStream : Stdinable {}
extension URL : Stdinable {}

public protocol Arguable : Sendable {}
extension Substring : Arguable {}
extension String : Arguable {}
extension URL : Arguable {}

public protocol Matchable {}
extension String : Matchable {}
extension Regex : Matchable {}
extension Substring : Matchable {}
extension Data : Matchable {}

extension ShellTest {

  public func run(withStdin: Stdinable? = nil, status: Int = 0, output: Matchable? = nil, error: Matchable? = nil, args: Arguable..., env: [String:String] = [:], cd: URL? = nil, _ validation : ((ProcessOutput) -> ())? = nil ) async throws {
    try await ShellProcess.run(cmd, withStdin: withStdin, status: status, output: output, error: error, args: args, env: env, cd: cd, validation)
  }

  public func run(withStdin: Stdinable? = nil, status: Int = 0, output: Matchable? = nil, error: Matchable? = nil, args: [Arguable], env: [String:String] = [:], cd: URL? = nil, _ validation : ((ProcessOutput) -> ())? = nil) async throws {
    try await ShellProcess.run(cmd, withStdin: withStdin, status: status, output: output, error: error, args: args, env: env, cd: cd, validation)
  }

  public func geturl(_ name : String? = nil) throws -> URL {
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

