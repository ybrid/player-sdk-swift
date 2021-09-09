// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let version = "0.13.0"

let package = Package(
    name: "YbridPlayerSDK",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "YbridPlayerSDK",
            targets: ["player-sdk-swift"]),
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
         .target(
             name: "player-sdk-swift",
             dependencies: [ "YbridOpus", "YbridOgg" ],
             path: "./player-sdk-swift",
             exclude: ["Info.plist"],
             resources: [.process("PlayerPackaging.txt")]
             ),
        .testTarget(
            name: "player-sdk-swiftTests",
            dependencies: [ "YbridPlayerSDK", "YbridOpus", "YbridOgg" ],
            path: "./player-sdk-swiftTests",
            exclude: ["Info.plist"],
            resources: [.process("unit/res"), .process("session/res")]
            ),
        .testTarget(
            name: "player-sdk-swiftUITests",
            dependencies: [ "YbridPlayerSDK", "YbridOpus", "YbridOgg" ],
            path: "./player-sdk-swiftUITests",
            exclude: ["Info.plist"]
            ),
        
        .binaryTarget(
            name: "YbridPlayerSDK",
            url: "https://github.com/ybrid/player-sdk-swift/releases/download//releases/download/\(version)/YbridPlayerSDK.xcframework.zip",
            checksum: "a9d5250839903b585601791c60d3a06215c65f8a3c51aba148f59e4d8f152040"
            ),
    ]
)

