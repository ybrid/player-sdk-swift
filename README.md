# player-sdk-swift
This audio player is written in Swift 4 and runs on iPhones and iPads from ios 9 to ios 14. 

An example app using this player SDK can be run from the XCode-Project in the repository [app-example-ios](https://github.com/ybrid/app-example-ios).

## Why yet another player?
This audio player offers
- low latency live streaming
- active, user-centric handling of typical network problems
- compatibility: currently supports audio codecs mp3, aac, and opus
- stability
  
## Integration 
### if you use CocoaPods 
The spec of the player-sdk is currently hosted at [ybrid/Private-Cocoapods](https://github.com/ybrid/Private-Cocoapods). The Cocoa Podfile of your project should look like
```ruby
platform :ios, '9.0'
install! 'cocoapods', :disable_input_output_paths => true
target 'app-example-ios' do
  use_frameworks!
  source 'git@github.com:ybrid/Private-Cocoapods.git'
  pod 'YbridPlayerSDK'
  target 'app-example-iosUITests' do
  end
end
```
### if you don't use CocoaPods
If you manage packages in another way you may take the XCFramewoks of this repository and embed them into your app project manually. From this repository take 
1. YbridPlayerSDK.xcframework from the root
2. /Pods/YbridOpus/YbridOpus.xcframework
3. /Pods/YbridOgg/YbridOgg.xcframework

and embedd them into your app project manually. Usually, you would copy these directories into a directory called 'Frameworks' of your project. In the properties editor, drag and drop them into the section 'Frameworks, Libraries and Embedded Content' of the target's 'General' tab.
Please report any issue to tell us your need.

## How to use
Four lines of swift code to listen to the your radio:
```swift
import YbridPlayerSDK
let url = URL.init(string: "https://stagecast.ybrid.io/adaptive-demo")!
let player = AudioPlayer(mediaUrl: url, listener: nil)
player.play()
// of course the program must not end here
```
As a developer, you probably want to receive changes of the playback state. Implement AudioPlayerListener and pass it to the AudioPlayer via the listener parameter above. You will also receive metadata, timing information, and hints on possible problems like network stalls. 
```swift
public protocol AudioPlayerListener : class {
    func stateChanged(_ state: PlaybackState)
    func displayTitleChanged(_ title: String?)
    func currentProblem(_ text: String?)
    func durationConnected(_ seconds: TimeInterval?)
    func durationReady(_ seconds: TimeInterval?)
    func durationPlaying(_ seconds: TimeInterval?)
    func durationBuffer(averagedSeconds: TimeInterval?, currentSeconds: TimeInterval?)
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
We use XCode version 12 with swift 4 and CocoaPods 1.10.
'YbridPlayerSDK.podspec' references the generated 'YbridPlayerSDK.xcframework'. It depends on pods 'YbridOpus' and 'YbridOgg' witch reference xcframeworks as well. So player-sdk-swift should be compatible with all versions of XCode and to swift down to version 4.
## Generating a new release
Choose a new version number, let's say ```0.4.2```. In the following steps you have to type that number three times. 

First generate a new 'YbridPlayerSDK.xcframework'.  
1. Open ```player-sdk-swift.xcworkspace``` with XCode. In the properties editor, on target ```player-sdk-swift``` select ```General``` and change ```Version``` to the new number. Close the workspace.
2. On a terminal, in the project's root directory execute
   ```shell 
   ./build.sh
   ```

Then publish the new YbridPlayerSDK.xcframework' to CocoaPods
1. Ensure the podspec is valid by executing
    ```shell
    ./pod_check.sh
2. Edit the version number in 'YbridPlayerSDK.podspec'. If you work in a branch, be sure to mention it 
    ```ruby
    s.version = '0.4.2'
    ...
    s.source = { :git => 'git@github.com:ybrid/player-sdk-swift', :branch => 'dev', :tag => s.version.to_s }
    ```
3. tag the git repository with the new version number
4. push everything including the tag to origin
5. call 
   ```shell
   ./pod_push.sh
   ```
and stay ready because you have to have to enter your password to the git repositories serveral times.
## further documentation
Where can I get more help?
A good start to dive into technical details is [the overview](https://github.com/ybrid/overview) 
## contributing
You are welcome to [contribute](https://github.com/ybrid/player-sdk-swift/CONTRIBUTING.md) in many ways.

# Licenses
This project uses [ogg-swift](https://github.com/ybrid/ogg-swift) and [opus-swift](https://github.com/ybrid/opus-swift) witch are MIT licensed. Ogg and Opus carry BSD licenses, see 3rd party section in [LICENSE](https://github.com/ybrid/app-example-ios/blob/master/LICENSE) file.