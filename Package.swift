// swift-tools-version: 6.1

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

import PackageDescription

// run tests like this:
// PATH=/usr/bin:/bin:/sbin TEST_ORIGINAL=1 swift test --no-parallel

let package = Package(
  name: "ShellTesting",
  // Mutex is only available in v15 or newer
  platforms: [.macOS(.v15)],
  products: [
    .library(name: "ShellTesting", targets: ["ShellTesting"])],
  dependencies: [
    .package(url: "https://github.com/r0ml/CMigration.git", branch: "main"),
  ],

  targets: [
    .target(name: "ShellTesting",
            dependencies: [
              .product(name: "CMigration", package: "CMigration"),
            ])
    ]
)
