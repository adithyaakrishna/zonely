// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "MeetingFinder",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "MeetingFinder", targets: ["MeetingFinder"])
  ],
  targets: [
    .executableTarget(
      name: "MeetingFinder",
      path: "Sources/MeetingFinder"
    ),
    .testTarget(
      name: "MeetingFinderTests",
      dependencies: ["MeetingFinder"],
      path: "Tests/MeetingFinderTests"
    ),
  ]
)
