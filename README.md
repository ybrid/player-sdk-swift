# Introduction

## player-sdk-swift

This audio player SDK is written in Swift 4 and runs on iPhones and iPads from iOS 9 to iOS 14.

An example app using this player SDK can be run from the XCode-Project in the repository [app-example-ios](https://github.com/ybrid/app-example-ios).

### Why yet another player?

This audio player SDK offers

* low latency live and on-demand file streaming
* compatibility: currently supports audio codecs mp3, aac, and opus
* metadata processing for Icecast, Vorbis commands and Ybrid 
* active, user-centric handling of typical network problems
* stability

### How to use

After [integrating](https://github.com/ybrid/player-sdk-swift#integration) the framework into your project, use the following lines of Swift code to listen to your radio:

```swift
import YbridPlayerSDK

let myEndpoint = MediaEndpoint(mediaUri: "https://democast.ybrid.io/adaptive-demo")
try AudioPlayer.open(for: myEndpoint, listener: nil) {
    (control) in /// called asychronously

    control.play()
    sleep(10) /// listen to audio

    control.stop()
    /// ...
    control.close()
}
sleep(10) /// of course the program must not end here
```

AudioPlayer.open first detects the transmission protocol and encoding of the audio content and metadata and then returns a playback control asynchronously. A media-specific control can be taken from the full `open` method, [see README\_Ybrid](readme_ybrid.md).

Possible playback states of the player are

```swift
public enum PlaybackState {
    case buffering 
    case playing 
    case stopped 
    case pausing 
}
```

With mediaUri addressing an on-demand file, you can safely use `control.pause()` if `control.canPause` is true.

As a developer, you probably want to receive changes of the playback state. Implement AudioPlayerListener and pass it via the listener parameter above. You will also receive changes of metadata, hints on problems like network stalls as well as relevant durations and playback buffer size.

```swift
public protocol AudioPlayerListener : class {
    func stateChanged(_ state: PlaybackState)
    func metadataChanged(_ metadata: Metadata)
    func error(_ severity:ErrorSeverity, _ exception: AudioPlayerError)
    func playingSince(_ seconds: TimeInterval?)
    func durationReadyToPlay(_ seconds: TimeInterval?)
    func durationConnected(_ seconds: TimeInterval?)
    func bufferSize(averagedSeconds: TimeInterval?, currentSeconds: TimeInterval?)
}
```

In case of network stalls, the state will change from playing to buffering at the time of exhausting audio buffer. Try it out! After reconnecting to a network, the player will resume.

Errors are raised when occurring. Your handling may use the message, the code, or just `ErrorSeverity`.

### Development environment

We use XCode version 12 with swift 4 and CocoaPods 1.10. According to the nature of evolved XCFrameworks, 'player-sdk-swift.xcworkspace' should be compatible with elder versions of XCode.

To generate the release artifact 'YbridPlayerSDK.xcframework', we use a shell script written for macOS's terminal, currently version 11.2. Since it wraps xcodebuild commands, it should be easily translated to other operating systems.

### Integration

'YbridPlayerSDK.xcframework' uses 'YbridOpus.xcframework' and 'YbridOgg.xcframework'.

#### If you use CocoaPods

The Cocoa Podfile of a project using this audio player should look like

```ruby
platform :ios, '9.0'
target 'app-example-ios' do
  use_frameworks!
  source 'https://github.com/CocoaPods/Specs.git'
  pod 'YbridPlayerSDK'
end
```

#### If you don't use CocoaPods

If you manage packages in another way, you may manually download the necessary XCFramewoks and embed them into your project. Take the following assets from the latest release 1. YbridPlayerSDK.xcframework.zip from [this repository/releases](https://github.com/ybrid/player-sdk-swift/releases) 2. YbridOgg.xcframework.zip from [ybrid/ogg-swift/releases](https://github.com/ybrid/ogg-swift/releases)  
3. YbridOpus.xcframework.zip from [ybrid/opus-swift/releases](https://github.com/ybrid/opus-swift/releases)

Unzip the files into a directory called 'Frameworks' of your XCode project. In the properties editor, drag and drop the directories into the section 'Frameworks, Libraries and Embedded Content' of the target's 'General' tab. Please report any issue to tell us your need.

### Further documentation

An excellent start to dive into technical details is [the overview](https://github.com/ybrid/overview).

For a deeper insight into the structure of metadata and the power of ybrid [see Ybrid docs](https://github.com/ybrid/player-interaction/blob/master/doc).

### Contributing

You are welcome to [contribute](https://github.com/ybrid/player-sdk-swift/blob/master/CONTRIBUTING.md) in many ways.

## Licenses

This project uses [ogg-swift](https://github.com/ybrid/ogg-swift) and [opus-swift](https://github.com/ybrid/opus-swift) which are MIT licensed. Ogg and Opus carry BSD licenses, see 3rd party section in the [LICENSE](https://github.com/ybrid/player-sdk-swift/blob/master/LICENSE) file.

