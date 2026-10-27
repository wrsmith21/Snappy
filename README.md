# Snappy

**Screenshot for sound.** Press a button while a podcast is playing, and Snappy saves that moment. Each "snap" keeps the cover art, the show and host, the episode, the timestamp, and a link back to where it came from.

## The idea

| Screenshot (today) | Snappy |
| --- | --- |
| Press side + volume buttons | Press **Snap**, double-tap your AirPods, or use the Action Button / Back Tap / Siri |
| Saves what's on screen | Saves the last 30 seconds of what you're hearing |
| Lands in Photos | Lands in a Snappy gallery with cover art, credits and a link to the source |

A snap always shows where it came from. Attribution and a link back to the original are built in, not optional.

## Status: iPhone, podcasts first

The first version is an iPhone app with a built-in podcast player. iOS doesn't let apps see what other apps are playing (see [`docs/FEASIBILITY.md`](docs/FEASIBILITY.md)), so you listen inside Snappy, and Snappy always knows exactly what to snap.

What works in v0.1:

- **Search** any podcast (iTunes Search API) and browse its episodes from the RSS feed
- **Play** in the background with lock screen / Control Center controls
- **Snap** from:
  - the Snap button in the mini player
  - your headphones' "next track" gesture (double-tap AirPods); can be turned off in Settings
  - the **Action Button**, **Back Tap** or **Siri** ("Snap that in Snappy") through the app's Shortcut, without opening the app
- **Gallery** of snaps showing cover art, episode, show · host, time range, and when you snapped it
  - **Play** replays just that clip, then **Keep listening** carries on from there
  - **Share** sends the source link with a credit line: `🎧 "Episode" — Show · Host [12:04–12:34]`
  - **Source** opens the episode page (or the show's Apple Podcasts page)
- Snap length: 15, 30 or 60 seconds

## Project layout

```
ios/
  project.yml         XcodeGen spec for the app (generates Snappy.xcodeproj)
  Snappy/             SwiftUI app: player, snap intent, views
  SnappyCore/         Swift package with the app's logic, unit tested
    Sources/          models, RSS parser, podcast search, clip window, snap storage
    Tests/
docs/FEASIBILITY.md   research: what exists, what each platform allows
```

## Running it

You need a Mac with Xcode 16+.

```sh
brew install xcodegen
cd ios
xcodegen generate
open Snappy.xcodeproj
```

Choose your team under *Signing & Capabilities*, then run on an iPhone or the simulator. AirPods gestures and the Action Button only work on a real device.

Run the core tests:

```sh
cd ios/SnappyCore && swift test
```

CI (`.github/workflows/ios.yml`) runs those tests and builds the app on every push that touches `ios/`.

## Next up

- Control Center and Lock Screen **Snap** button (iOS 18 control widget)
- Export a snap as an audio file / share card (cover art + waveform)
- Transcripts of each clip, notes and tags
- Subscriptions and a "continue listening" list
- Android, which can snap from *other* podcast apps (see feasibility notes)
