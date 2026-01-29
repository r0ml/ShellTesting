
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


// Helper that erases any Regex<Output> to Regex<AnyRegexOutput>
func eraseToAnyRegex(_ value: Any) -> Regex<AnyRegexOutput>? {
    // Try the common concrete cases first
    if let r = value as? Regex<AnyRegexOutput> { return r }
    if let r = value as? Regex<String> { return Regex<AnyRegexOutput>(r) }
    if let r = value as? Regex<Substring> { return Regex<AnyRegexOutput>(r) }

    // Fall back to a generic-erasure path using reflection on the generic type
    // We can't write `if let r = value as? Regex<some Output>` directly,
    // but we can attempt to dynamically call a generic function.
    func eraseGeneric<Output>(_ r: Regex<Output>) -> Regex<AnyRegexOutput> {
        Regex<AnyRegexOutput>(r)
    }

    // Attempt to cast to the existential `Any`-boxed generic and re-dispatch
    if let anyRegex = value as? any AnyRegexBox {
        return anyRegex.erase()
    }

    // As a last resort, try a mirror-based bridge for Regex<tuple> cases:
    // If you control the inputs, prefer routing them through AnyRegexBox below.
    return nil
}

// A small box protocol to enable dynamic erasure of Regex<Output>
private protocol AnyRegexBox {
    func erase() -> Regex<AnyRegexOutput>
}

extension Regex: AnyRegexBox {
    func erase() -> Regex<AnyRegexOutput> {
        Regex<AnyRegexOutput>(self)
    }
}
