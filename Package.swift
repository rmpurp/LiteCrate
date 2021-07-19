// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "LiteCrate",
  platforms: [
    .macOS(.v12),
    .iOS(.v15),
  ],
  products: [
    // Products define the executables and libraries a package produces, and make them visible to other packages.
    .library(
      name: "LiteCrate",
      targets: ["LiteCrate"])
  ],
  dependencies: [
    .package(
      name: "FMDB",
      url: "https://github.com/ccgus/fmdb",
      .upToNextMinor(from: "2.7.7"))

  ],
  targets: [
    // Targets are the basic building blocks of a package. A target can define a module or a test suite.
    // Targets can depend on other targets in this package, and on products in packages this package depends on.
    .target(
      name: "LiteCrate",
      dependencies: [
        .byName(name: "FMDB")
      ]),
    .testTarget(
      name: "LiteCrateTests",
      dependencies: ["LiteCrate"]),
  ]
)
