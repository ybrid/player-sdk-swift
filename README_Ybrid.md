# How to use Ybrid features
This audio player SDK supports features to affect the audio content being played to the user. The ybrid interaction protocol is based on a connection between server and client to hold states and to control playback. 


## Ybrid features are
- winding backward and forward in time
- winding to a specific time
- winding back to live
- skipping items backward and forward, for example skipping back to the lastest news, to next music, ...
- swapping the item to alternative content within the same timeslot 
- swapping the service / the channel. Many broadcasters provide more content than the primary radio programm does. For example special event channels, party loop channels, different listening perspectves ...

## How to use
After [integrating](https://github.com/ybrid/player-sdk-swift#integration) the framework into your project, use the following lines of Swift code to access ybrid features:
```swift
import YbridPlayerSDK

let swr3Endpoint = MediaEndpoint(mediaUri: "http://swr-swr3.cast.ybrid.io/swr/swr3/ybrid").forceProtocol(.ybridV2)

try AudioPlayer.open(for: swr3Endpoint, listener: nil, playbackControl: nil) {
    (ybridControl) in /// called asychronously

    ybridControl.play()
    sleep(2)
    ybridControl.skipBackward(ItemType.NEWS)
    sleep(10) /// listen to the news

    ybridControl.stop()
    /// ...
    ybridControl.close()
}
sleep(12) /// of course the program must not end here
```

The signature of ```AudioPlayer.open``` has two callback parameters. The media protocol spoken with the endpoint decides which one is called (asynchronously).
```swift
func open(for endpoint:MediaEndpoint, listener: AudioPlayerListener?,
            playbackControl: ((PlaybackControl)->())? = nil,
              ybridControl: ((YbridControl)->())? = nil )
```
- ```playbackControl``` is called for endpoints using icecast servers or plain http streaming. ```PlaybackControl``` offers the basic set of actions like ```play()```...
- ```ybridControl``` is called if, behind the scenes, there is a ybrid server detected. Or if you told the endpoint by ```endpoint.forceProtocol(.ybridV2)```. 
  
```YbridControl``` extends ```PlaybackControl```. It allows the following actions on the audio playing:

```swift
public protocol YbridControl : PlaybackControl {  
    
    /// time shifting
    var offsetToLiveS:TimeInterval { get }
    func wind(by:TimeInterval)
    func wind(to:Date)
    func windToLive(_ carriedOut: (()->())?)
    func skipForward(_ type:ItemType?)
    func skipBackward(_ type:ItemType?)
    
    /// change content
    var swapsLeft:Int { get }
    func swapItem(_ carriedOut: (()->())?)
    var services:[Service] { get }
    func swapService(to id:String, _ carriedOut: (()->())?)

    /// refresh all states, all methods of the YbridControlListener are called
    func select() 
}
```
If you call an action it'll take a short time until you hear the requested change of audio content. ```carriedOut``` hooks of an action is called when the requested changeover is fullfilled. Use these callbacks to express the change in the user interface.

Implement YbridControlListener and pass it via the listener parameter of ```AudioPlayer.open```. You will recieve the following notifications on startup and when the value changes
```swift
public protocol YbridControlListener : AudioPlayerListener {
    func offsetToLiveChanged(_ offset:TimeInterval?)
    func swapsChanged(_ swapsLeft:Int)
    func servicesChanged(_ services:[Service])
}
```

## Metadata
We do not (yet) guess metadata. We read metadata 
- encoded in the icyx transport layer, called icy-Metadata
- encoded in the opus codec, called VorbisComments in OpusTags
- maintained by the ybrid server. The data is taken in parallel to audio stream injection.

In context of ybrid metadata we currently support the folling ```ItemTypes```
```swift
public enum ItemType : String  {
    case ADVERTISEMENT = "ADVERTISEMENT"
    case COMEDY = "COMEDY"
    case JINGLE = "JINGLE"
    case MUSIC = "MUSIC"
    case NEWS = "NEWS"
    case TRAFFIC = "TRAFFIC"
    case VOICE = "VOICE"
    case WEATHER = "WEATHER"
    case UNKNOWN
}
```

## Ybrid docs
For a deeper insight into the structure of metadata and the power of ybrid [see ybrid docs](https://github.com/ybrid/player-interaction/blob/master/doc) and [ybrid server specs](https://github.com/ybrid/overview/blob/master/specification/README.md)