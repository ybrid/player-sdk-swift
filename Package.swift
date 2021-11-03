// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let version = "0.13.2"
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
                "YbridPlayerSDK"
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
        .binaryTarget(
           name: "YbridPlayerSDK",
           url: "https://github.com/ybrid/player-sdk-swift/releases/download/\(version)/YbridPlayerSDK.xcframework.zip",
            checksum: "d2c4ec2ceb5272e6827714fa7ca64bbdc0182a4177a8c9b36921f97934628a26"
           )
    ]
)

