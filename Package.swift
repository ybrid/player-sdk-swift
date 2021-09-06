// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "YbridPlayerSDK",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "YbridPlayerSDK",
            targets: ["YbridPlayerSDK"]),
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
            name: "YbridPlayerSDK",
            dependencies: [ "YbridOpus", "YbridOgg" ],
            path: "./player-sdk-swift",
            exclude: ["Info.plist"]
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
    ]
)
