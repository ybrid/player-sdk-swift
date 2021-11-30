# More interfaces

### product version

If we're talking about the product version it's easy to get the evolution of the SDK using the following:

```swift
AudioPlayer.productName
AudioPlayer.productVersion
AudioPlayer.productBuildNumber
```

### memory issues

The SDK offers a way to prohibit crashes when running out of memory.

Call `PlayerContext.handleMemoryLimit()` on the first sign of trouble. If the memory footprint of the whole app exceeds `PlayerContext.memoryLimitMB`, the SDK will stop loading audio content. As a result the audio will be truncated and the problem is communicated via `AudioPlayerListener.error`.

The default value of `memoryLimitMB` is 128 megabytes. You should adjust the value to your need, if you use `handleMemoryLimit`.

An example of handling out of memory in your app could look like this in your `ViewController`

```swift
override func didReceiveMemoryWarning() {
    Logger.shared.notice()
    if PlayerContext.handleMemoryLimit() {
        Logger.shared.error("player handled memory limit of \(PlayerContext.memoryLimitMB) MB")
    }
    super.didReceiveMemoryWarning()
}
```
