// swift-tools-version: 6.2
// SPDX-License-Identifier: 0BSD
import PackageDescription

let common: [SwiftSetting] = [.enableUpcomingFeature("InferIsolatedConformances")]
var products: [Product] = [
  .library(name: "MallowKit", targets: ["MallowKit"]),
  .executable(name: "mallow", targets: ["MallowCLI"]),
]
var targets: [Target] = [
  .systemLibrary(name: "CArchive"),
  .target(name: "MallowKit", dependencies: ["CArchive"], swiftSettings: common),
  .executableTarget(name: "MallowCLI", dependencies: ["MallowKit"], swiftSettings: common),
  .testTarget(name: "MallowKitTests", dependencies: ["MallowKit", "CArchive"], exclude: ["Fixtures"], swiftSettings: common),
]
#if os(macOS)
products.append(.executable(name: "MallowApp", targets: ["MallowApp"]))
targets.append(.executableTarget(name: "MallowApp", dependencies: ["MallowKit"], swiftSettings: common))
#endif
let package = Package(name: "Mallow", platforms: [.macOS(.v15)], products: products, targets: targets)
