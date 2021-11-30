# Metadata

We do not \(yet\) guess metadata. We read metadata

* encoded in the icyx transport layer, in short icy metadata
* encoded in the opus codec, called [VorbisComments](https://xiph.org/vorbis/doc/v-comment.html) contained in OpusTags
* maintained by the ybrid server. The data is taken in parallel to audio stream injection.

```swift
AudioPlayerListener.metadataChanged( _ metadata:Metadata )
```
is called by the SDK on appropriate moments. The `Metadata` interface provides access to the following values.

## `.displayTitle`
contains a short text describing the currently playing content to be displayed to the user. It's a shortcut of `current.displayTitle`. 
## `.current`
An `item` representing the content currently beeing played. Consider this data to be invalid if the player is `stopped`, because it could be out of date. 
## `.service`
Information about the service that delivers the items. A `service` object is always provided and the values are valid until the active service changes (see [Ybrid feature swapService](readme_ybrid.md)). 
## `.next`
If known, the next content. The `item`, representing the content beeing played after the current content ends.

## `item` metadata
Access to an item struct describing the content. 
- `displayTitle` answers the user's question 'What am I listening to?'.

The following fields are optional.
- `ìdentifier` a unique id representing this item. It may become mandatory in future.
- `title`, `artist`, `genre`
contain the estalished information.
- `album`, `version`
name and version of the collection (see [Vorbis Comments](https://xiph.org/vorbis/doc/v-comment.html)).
- `description`, `infoUri`
A text, an uri defining a page containing information coming along with the specific content.
- `playbackLength`
The duration of the content in milliseconds. It may be inaccurate and could change during playback. 
- `companions`
An array of urls pointing to pictures coming along with the content. Still implementation specific.
- `type`
We currently support the following `ItemTypes`. It may be extended in future.
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
## `service` metadata
Data about source and delivery of audio items. A service is responsible for providing the seqeunce of items. 
- `identifier`
An id representing this service is mandatory. 
- `displayName`
User information about the source, for example the broadcaster or name of a playlist. It may be an empty string.
- `iconUri`
Url to an icon that can represent this service in a gui. For example, the logo of the radio station.
- `genre`
Type of content beeing provided by this service - not equal to `item.genre`.
- `description`, `infoUri`
A text, a web site uri providing information about the service. 


