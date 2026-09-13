# Synthetic media fixtures

The generated files in `generated/` are ignored. They are one-second 440 Hz synthetic tones, not copyrighted music. Recreate them with the local FFmpeg build:

```powershell
ffmpeg -y -f lavfi -i "sine=frequency=440:duration=1" -ac 2 -ar 48000 -c:a libmp3lame generated/tone.mp3
ffmpeg -y -f lavfi -i "sine=frequency=440:duration=1" -ac 2 -ar 48000 -c:a aac generated/tone.m4a
ffmpeg -y -f lavfi -i "sine=frequency=440:duration=1" -ac 2 -ar 48000 -c:a aac generated/tone.mp4
ffmpeg -y -f lavfi -i "sine=frequency=440:duration=1" -ac 2 -ar 48000 -c:a flac generated/tone.flac
ffmpeg -y -f lavfi -i "sine=frequency=440:duration=1" -ac 2 -ar 48000 -c:a pcm_s16le generated/tone.wav
ffmpeg -y -f lavfi -i "sine=frequency=440:duration=1" -ac 2 -ar 48000 -c:a libopus generated/tone.opus
ffmpeg -y -f lavfi -i "sine=frequency=440:duration=1" -ac 1 -ar 44100 -c:a pcm_s16le generated/tone-44100-mono.wav
```

Synthetic fixtures prove deterministic container/decoder plumbing only. Final ADR evidence must also use user-authorized real media with tags, cover art, variable bitrates, longer duration, special paths and damaged files. Do not commit those files by default; record codec/container, provenance, permission and SHA-256 in a local manifest.

Run the opt-in native checks on Windows with an available output device:

```powershell
cargo test --manifest-path ../../src-tauri/Cargo.toml -- --ignored --nocapture --test-threads=1
```

Run from this directory. The format test loads WAV (48 kHz stereo / 44.1 kHz mono), FLAC, MP3, M4A/AAC and Opus through the production engine, muted, and waits for completion. Other opt-in tests verify automatic queue advancement and an actual ffprobe process. These checks do not write the user's library or preferences.

## Current candidate licenses

- Symphonia 0.6.1: MPL-2.0 dependency; Heni does not modify or copy its source.
- CPAL 0.18.2: Apache-2.0.
- symphonia-adapter-libopus 0.3.0: MIT OR Apache-2.0; bundled libopus uses the Opus license.
- ringbuf 0.4.8: MIT OR Apache-2.0.
- rubato 5.0.0 and its audioadapter components: MIT OR Apache-2.0.
- libmpv2 6.0.0: LGPL-2.1 binding; the selected mpv binary configuration has separate LGPL/GPL distribution implications and is not yet bundled.
