# Feasibility notes

_Last updated: 2026-10-27_

## 1. Does this already exist?

Parts of it do. I couldn't find the whole thing (one button that works in **any** app, across podcasts, music and audiobooks).

| Product | What it does | Gap vs. Snappy |
| --- | --- | --- |
| **Snipd** | Tap your headphones to "snip" a podcast moment; AI adds transcript and summary | Only works inside Snipd's own player; podcasts (plus some audiobooks/YouTube) |
| **Overcast** | Share a clip (up to 1 min) of an episode with a link back | Only inside Overcast; manual, not a one-tap capture |
| **Spotify / Apple Podcasts / Pocket Casts** | Share an episode from a timestamp | Only inside each app; no saved gallery |
| **Shazam** | Identifies music playing nearby | Identifies the song but doesn't save the moment or a clip |
| **Reclip** | Keeps the last 2 min from the **microphone** | Records the room, not what's playing; no metadata |

**What's open:** a capture button that works **across apps**, plus a personal gallery of "sound screenshots" with proper attribution.

## 2. Is it feasible?

Yes, with one important design choice: **capture the moment (metadata + timestamp), not necessarily the raw audio.** Copying another app's audio stream is the hard part, both technically and legally. Knowing *what* is playing and *where* you are in it is mostly solvable.

### Android: most feasible

| Need | How | Notes |
| --- | --- | --- |
| What's playing (title, artist, art, position) in **any** app | `NotificationListenerService` + `MediaSessionManager.getActiveSessions()` | User grants notification access once. Works with Spotify, YouTube, podcast apps, Audible. |
| The actual audio | `AudioPlaybackCapture` API (Android 10+) | Needs a screen-capture consent prompt each session and a persistent notification. Apps can opt out (`allowAudioPlaybackCapture=false`), and DRM'd music apps likely do. A continuous rolling buffer drains battery. |
| "Screenshot-style" button | Quick Settings tile, home-screen widget, notification action, or an accessibility shortcut | Remapping hardware button combos needs an AccessibilityService, which risks Google Play policy rejection. Avoid it. |

### iOS: feasible with constraints

| Need | How | Notes |
| --- | --- | --- |
| What's playing in **other** apps | No system-wide API. Use per-service APIs: **Spotify Web API** (`/me/player/currently-playing` gives track/episode + `progress_ms`), **MusicKit** for Apple Music | Apple Podcasts, Overcast, Audible etc. don't expose this. Fallback: the user picks from recent history or audio fingerprinting (ShazamKit). |
| The actual audio | **Not possible.** iOS apps can't record other apps' audio | Rebuild the clip from the source instead (see below). |
| "Screenshot-style" button | **Action Button** (iPhone 15 Pro and later), **Back Tap**, Control Center / Lock Screen control (iOS 18+), Siri ("Hey Siri, snap that") via App Intents | Apps can't bind side + volume buttons, but these options are just as quick. |

### Getting the audio clip without recording it

- **Podcasts:** episodes are public MP3s in RSS feeds. With the show and timestamp, a backend can fetch exactly that segment (HTTP range request + ffmpeg trim). This is how Overcast/Snipd-style clips work. This is the best category for real clips.
- **Music:** don't redistribute the audio. Save a **deep link at the timestamp** and show the official 30-second preview where one is available (Apple Music API still offers previews; Spotify deprecated `preview_url` in late 2024).
- **Audiobooks:** usually DRM-protected (Audible, Apple Books). Save metadata + timestamp + deep link only.

### Legal and licensing

- Attribution plus a link back helps creators, but **attribution doesn't grant rights to copy**. Keep clips short, for personal use, and sharing should send people to the original source.
- Podcast clips for personal or commentary use are common practice (Overcast, Snipd, Spotify all do it); still get a proper legal review before launch.
- Music clips are the highest risk. Use links and official previews only.

## 3. Proposed MVP

1. **Android first**: full cross-app metadata, real clips via `AudioPlaybackCapture` where allowed.
2. **Snap = metadata + timestamp + deep link + cover art**, with an audio clip where available.
3. **Podcasts as the hero use case**: real clips pulled from RSS, then transcript (Whisper or similar).
4. **iOS v1**: Action Button / Control Center snap → Spotify + Apple Music via their APIs, podcasts via RSS lookup.
5. Gallery with share cards (cover art + waveform + "Listen on …" link).

### Suggested stack

- **Mobile:** native Kotlin (Android) + Swift (iOS). The system integrations (media sessions, App Intents, Control Center widgets) are hard to do well from cross-platform frameworks.
- **Backend:** small API for podcast lookup (Podcast Index / iTunes Search API), RSS segment extraction (ffmpeg), transcripts, share-card rendering.

## 4. Open questions

- Is a rolling audio buffer on Android worth the battery and consent-prompt friction, or should Android also use "rebuild the clip from the source"?
- How long should a snap be by default: last 15s, 30s, or 60s?
- Social layer (public snaps, following people) or a private notebook first?
