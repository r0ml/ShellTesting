
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

public final actor AsyncDataActor {
  var d : [Data]
  var delay : Double
  var first = true

  public init(_ d : [Data], delay : Double = 0.5) {
    self.d = d
    self.delay = delay
  }

  func consumeD() -> Data? {
    if self.d.isEmpty { return nil }
    let d = self.d.removeFirst()
    return d
  }

  func notFirst() {
    self.first = false
  }

  public nonisolated var stream : AsyncStream<Data> {
    return AsyncStream(unfolding: {
      if await self.first {
        await self.notFirst()
      } else {
        try? await Task.sleep(nanoseconds: UInt64(Double(NSEC_PER_SEC) * self.delay) )
      }
      let d = await self.consumeD()
      return d
    })
  }
}

