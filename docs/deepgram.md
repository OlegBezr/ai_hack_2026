# Deepgram speech (STT + TTS) via REST

We use Deepgram for both directions of speech, over **plain REST** — no WebSocket,
no streaming, no Web Audio interop. A button-driven round-trip is enough for the
demo and is verifiable in minutes:

- **Speech → Text:** record a clip with the mic, POST the bytes to `/v1/listen`,
  read the transcript.
- **Text → Speech:** POST text to `/v1/speak`, get MP3 bytes back, play them.

Docs: <https://developers.deepgram.com/home>

The Dart implementation lives in `dream_book/lib/deepgram/` and the demo screen in
`dream_book/lib/demos/deepgram_demo.dart` (reachable from the home launcher).

> Streaming/realtime (live captions, voice barge-in) is a later upgrade: swap only
> the STT half for a WebSocket connection to `wss://api.deepgram.com/v1/listen`.
> Everything else (TTS, recording, playback) stays the same.

---

## Auth

A single API key, sent as a header. No OAuth.

```
Authorization: Token <DEEPGRAM_KEY>
```

The key is read from the bundled `.env` (`DEEPGRAM_KEY`, loaded by `dotenv` in
`main()`). Keep it server-side / proxied for production; it ships in the app only
because this is a prototyping build.

---

## Speech → Text — `POST /v1/listen` (prerecorded)

Record to a file, then send the raw bytes. **Match the content-type to how you
recorded.** Deepgram sniffs most containers, but an honest content-type avoids
surprises — so we record **WAV / linear16** and send `audio/wav`.

```dart
final res = await http.post(
  Uri.parse('https://api.deepgram.com/v1/listen?model=nova-3&smart_format=true'),
  headers: {
    'Authorization': 'Token $deepgramKey',
    'Content-Type': 'audio/wav', // must match the recording format
  },
  body: audioBytes, // Uint8List read from the recorded file
);

final transcript = jsonDecode(res.body)
    ['results']['channels'][0]['alternatives'][0]['transcript'];
```

- `model=nova-3` — latest general model.
- `smart_format=true` — punctuation/capitalisation, good for a prompt.
- An empty `transcript` means silence / no speech — not an error.

### Recording with `record`

`RecordConfig()`'s default encoder is **AAC (`.m4a`)**, *not* WAV — so don't
hardcode `audio/wav` against the defaults. Ask for WAV explicitly:

```dart
final rec = AudioRecorder();
if (!await rec.hasPermission()) { /* mic denied */ }

final dir = await getTemporaryDirectory();          // path_provider
final path = '${dir.path}/clip.wav';

await rec.start(
  const RecordConfig(
    encoder: AudioEncoder.wav,                       // honest audio/wav
    sampleRate: 16000,
    numChannels: 1,
  ),
  path: path,
);                                                   // tap to start
final outPath = await rec.stop();                    // tap to stop → outPath
```

`record` hands back a **filesystem path on native** and a **blob URL on web**, so
reading the bytes differs by platform — see the web note below.

---

## Text → Speech — `POST /v1/speak`

Text in, MP3 bytes out.

```dart
final res = await http.post(
  Uri.parse('https://api.deepgram.com/v1/speak?model=aura-2-thalia-en'),
  headers: {
    'Authorization': 'Token $deepgramKey',
    'Content-Type': 'application/json',
  },
  body: jsonEncode({'text': pageText}),
);
// res.bodyBytes is MP3 audio.
```

### Playing with `just_audio`

`just_audio` plays from a **file or URL, not raw bytes** — so write the MP3 to a
temp file and point the player at it:

```dart
final dir = await getTemporaryDirectory();
final file = '${dir.path}/tts.mp3';
await File(file).writeAsBytes(res.bodyBytes, flush: true);

await player.setFilePath(file);
await player.play();
```

Barge-in / interrupt = `await player.stop();` (we stop before each new `speak()`
so a fresh tap cleanly replaces in-flight audio).

---

## Dependencies & platform setup

```
record          # mic recording → file
just_audio      # MP3 playback
path_provider   # temp dir for the clip / tts files
http            # REST calls (already used elsewhere)
```

**Native is the priority** — `record` and `just_audio` work out of the box there,
without the Web Audio interop that makes the browser path fiddly.

Permissions (added):
- iOS — `NSMicrophoneUsageDescription` in `ios/Runner/Info.plist`.
- Android — `RECORD_AUDIO` (and `INTERNET`) in `AndroidManifest.xml`.

**Web caveat.** `dart:io`'s `File` doesn't exist on web, so byte read/write is
routed through a conditional import (`lib/deepgram/read_bytes.dart` →
`read_bytes_io.dart` / `read_bytes_web.dart`). On web, `record` returns a blob URL
(fetched over http) and `just_audio`'s temp-file playback isn't wired up — the web
build compiles, but STT/TTS are native-first by design. Add a blob/data-URL audio
source if you need TTS in the browser.

---

## Files

| File | Role |
| ---- | ---- |
| `lib/deepgram/deepgram_service.dart` | `transcribe()` + `speak()` REST client, reads `DEEPGRAM_KEY`. |
| `lib/deepgram/read_bytes.dart` (+ `_io`/`_web`) | Platform byte read/write for the recorded clip and TTS file. |
| `lib/demos/deepgram_demo.dart` | Tabbed demo screen: record → transcript, and text → spoken audio. |
