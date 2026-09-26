// swift-tools-version: 6.2
// SPDX-License-Identifier: 0BSD
import PackageDescription

let common: [SwiftSetting] = [.enableUpcomingFeature("InferIsolatedConformances")]

let package = Package(
  name: "Mallow",
  platforms: [.macOS(.v15)],
  products: [.library(name: "MallowKit", targets: ["MallowKit"])],
  targets: [
    .target(name: "MallowKit", swiftSettings: common),
    .testTarget(
      name: "MallowKitTests", dependencies: ["MallowKit"],
      exclude: ["Fixtures"], swiftSettings: common
    ),
  ]
)
