# player-sdk-swift
This audio player is written in Swift 4 and runs on iPhones and iPads from ios 9 to ios 14. 

An example app using this player SDK can be run from the XCode-Project in the repository [app-example-ios](https://github.com/ybrid/app-example-ios).

## Why yet another player?
This audio player offers
- low latency live streaming
- active, user-centric handling of typical network problems
- compatibility: currently supports audio codecs mp3, aac, and opus
- stability

## How to use
After [integrating](https://github.com/ybrid/player-sdk-swift#integration) the Framework into your project, use the following lines of Swift code to listen to your radio:
```swift
import YbridPlayerSDK

let url = URL.init(string: "https://stagecast.ybrid.io/adaptive-demo")!
let player = AudioPlayer(mediaUrl: url, listener: nil)
player.play()
// of course the program must not end here
```
As a developer, you probably want to receive changes of the playback state. Implement AudioPlayerListener and pass it to the AudioPlayer via the listener parameter above. You will also receive changes of metadata, hints on problems like network stalls as well as relevant durations and playback buffer size.
```swift
public protocol AudioPlayerListener : class {
    func stateChanged(_ state: PlaybackState)
    func displayTitleChanged(_ title: String?)
    func currentProblem(_ text: String?)
    func playingSince(_ seconds: TimeInterval?)
    func durationReadyToPlay(_ seconds: TimeInterval?)
    func durationConnected(_ seconds: TimeInterval?)
    func bufferSize(averagedSeconds: TimeInterval?, currentSeconds: TimeInterval?)
}
```
The PlaybackStates are 
```swift
public enum PlaybackState {
    case buffering
    case playing
    case stopped
}
```
In case of network stalls, the state will change from playing to buffering at the time of exhausting audio buffer. Try it out! After reconnecting to a network, the player will resume.

## Development environment
We use XCode version 12 with swift 4 and CocoaPods 1.10. According to the nature of evolved XCFrameworks, 'player-sdk-swift.xcworkspace' should be compatible with elder versions of XCode. 

To generate the release artifact 'YbridPlayerSDK.xcframework', we use a shell script written for macOS's terminal, currently version 11.2. Since it wraps xcodebuild commands, it should be easily translated to other operating systems.

## Integration 
'YbridPlayerSDK.xcframework' uses 'YbridOpus.xcframework' and 'YbridOgg.xcframework'. 

### if you use CocoaPods 
The Cocoa Podfile of a project using this audio player, should look like
```ruby
platform :ios, '9.0'
target 'app-example-ios' do
  use_frameworks!
  source 'https://github.com/CocoaPods/Specs.git'
  pod 'YbridPlayerSDK'
end
```
### if you don't use CocoaPods
If you manage packages in another way, you may manually download the necessary XCFramewoks and embed them into your project. Take the following assets from the latest release
1. YbridPlayerSDK.xcframework.zip from [this repository/releases](https://github.com/ybrid/player-sdk-swift/releases)
2. YbridOgg.xcframework.zip from [ybrid/ogg-swift/releases](https://github.com/ybrid/ogg-swift/releases)  
3. YbridOpus.xcframework.zip from [ybrid/opus-swift/releases](https://github.com/ybrid/opus-swift/releases) 

Unzip the files into a directory called 'Frameworks' of your XCode project. In the properties editor, drag and drop the directories into the section 'Frameworks, Libraries and Embedded Content' of the target's 'General' tab. 
Please report any issue to tell us your need.

## Further documentation
An excellent start to dive into technical details is [the overview](https://github.com/ybrid/overview) 

## Contributing
You are welcome to [contribute](https://github.com/ybrid/player-sdk-swift/blob/master/CONTRIBUTING.md) in many ways.

# Licenses
This project uses [ogg-swift](https://github.com/ybrid/ogg-swift) and [opus-swift](https://github.com/ybrid/opus-swift) witch are MIT licensed. Ogg and Opus carry BSD licenses, see 3rd party section in [LICENSE](https://github.com/ybrid/app-example-ios/blob/master/LICENSE) file.
