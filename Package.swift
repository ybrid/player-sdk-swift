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
//        .package(
//            name: "YbridOpus",
//            path: "../../github/opus-swift/OpusSwiftLocal")
        
        .package(
            name: "YbridOpus",
            url: "git@github.com:ybrid/opus-swift.git",
            from: "0.8.0"),

//        .package(
//            name: "YbridOgg",
//            path: "../../github/ogg-swift/OggSwiftLocal"),
        
        .package(
            name: "YbridOgg",
            url: "git@github.com:ybrid/ogg-swift.git",
            from: "0.8.0"),
    ],
    targets: [

// use binary target only for build and releases
        .binaryTarget(
           name: "YbridPlayerSDK",
           url: "https://github.com/ybrid/player-sdk-swift/releases/download/\(version)/YbridPlayerSDK.xcframework.zip",
            checksum: "66048b2581c476433be214c5d6a9b3b5427f57803c8d78e76a2af3df47fac828"
           ),
// use this for integration tests on built target or during deelopment
        .testTarget(
           name: "YbridPlayerSDK-PlatformTests",
           dependencies: [ "YbridPlayerSDK", "YbridOpus", "YbridOgg" ],
           path: "./player-sdk-swiftUITests",
           exclude: ["Info.plist"]
           ),

// use this targets only during development and unit tests
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

    ]
)

