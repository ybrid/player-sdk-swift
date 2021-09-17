// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let version = "0.13.0"
let package = Package(
    name: "YbridPlayerSDK",
    platforms: [
        .macOS(.v10_10), .iOS(.v9)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "YbridPlayerSDK",
            targets: [
                "YbridPlayerSDK",
//                "YbridPlayerSDK-UnitTests",
                "YbridPlayerSDK-PlatformTests"
            ]),
    ],
    dependencies: [
        .package(
            name: "YbridOpus",
            url: "git@github.com:ybrid/opus-swift.git",
            from: "0.8.0"),
        .package(
            name: "YbridOgg",
            url: "git@github.com:ybrid/ogg-swift.git",
            from: "0.8.0"),
    ],
    targets: [

// binary target only for builds and releases
        .binaryTarget(
           name: "YbridPlayerSDK",
           url: "https://github.com/ybrid/player-sdk-swift/releases/download/\(version)/YbridPlayerSDK.xcframework.zip",
            checksum: "81ee05ef4797bb3630c7f35994a68a51f56032d9b4f1f53235437398739a05c2"
           ),

// targets only during development
//         .target(
//             name: "YbridPlayerSDK",
//             dependencies: [ "YbridOpus", "YbridOgg" ],
//             path: "./player-sdk-swift",
//             exclude: ["Info.plist"],
//             resources: [.process("PlayerPackaging.txt")]
//             ),
//        .testTarget(
//            name: "YbridPlayerSDK-UnitTests",
//            dependencies: [ "YbridPlayerSDK", "YbridOpus", "YbridOgg" ],
//            path: "./player-sdk-swiftTests",
//            exclude: ["Info.plist"],
//            resources: [.process("unit/res"), .process("session/res")]
//            ),

// target for testing of built target and during development
        .testTarget(
           name: "YbridPlayerSDK-PlatformTests",
           dependencies: [ "YbridPlayerSDK", "YbridOpus", "YbridOgg" ],
           path: "./player-sdk-swiftUITests",
           exclude: ["Info.plist"]
           ),
    ]
)

