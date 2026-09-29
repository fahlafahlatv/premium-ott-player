# TIVIO

TIVIO is a new, dark, premium live-TV experience built with Flutter. It includes:

- Live video playback using `video_player` and `chewie`
- M3U playlist parsing with category and logo support
- Search, favorites, category navigation, and channel details
- Automatic stream recovery with a retry countdown
- Responsive landscape layout with a collapsible sidebar
- A local demo playlist so the UI works before a provider is configured

## Run

```bash
flutter pub get
flutter run
```

## Configure a playlist

Pass an M3U URL to `TivioApp` or replace `TivioConfig.playlistUrl` in `lib/main.dart`.
Only use playlists and streams that you are authorized to access.

```dart
runApp(const TivioApp(playlistUrl: 'https://example.com/playlist.m3u'));
```
