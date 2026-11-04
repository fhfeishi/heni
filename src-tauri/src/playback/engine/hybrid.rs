use super::{EngineObservation, NativeAudioEngine, PlaybackEngine};
use crate::playback::{
    contracts::{MediaKind, PlaybackError, PlaybackItem},
    video::VideoRuntime,
};

pub(crate) struct HybridEngine {
    audio: NativeAudioEngine,
    video: VideoRuntime,
}
impl HybridEngine {
    pub(crate) fn new(video: VideoRuntime) -> Self {
        Self {
            audio: NativeAudioEngine::default(),
            video,
        }
    }
}
impl PlaybackEngine for HybridEngine {
    fn load(
        &mut self,
        item: &PlaybackItem,
        position_ms: u64,
        playing: bool,
        volume: f64,
        muted: bool,
    ) -> Result<Option<u64>, PlaybackError> {
        if item.kind == MediaKind::Video {
            self.video
                .load(item, position_ms, playing, volume, muted, || {
                    self.audio.stop()
                })?;
            Ok(item.duration_ms)
        } else {
            // The frontend acknowledges a manual video pause. Automatic advance has no
            // such handshake, so retire the video output here instead of refusing the
            // load: a refused load used to mark the whole session failed forever.
            self.video.stop();
            self.audio.load(item, position_ms, playing, volume, muted)
        }
    }
    fn set_playing(&mut self, playing: bool) -> Result<(), PlaybackError> {
        if self.video.observation().is_some() {
            self.video.change(|intent| intent.playing = playing);
            Ok(())
        } else {
            self.audio.set_playing(playing)
        }
    }
    fn stop(&mut self) {
        self.audio.stop();
        self.video.stop();
    }
    fn prepare_for_next(&mut self) {
        // A stale video observation otherwise masks the audio engine's completion.
        self.video.stop();
        self.audio.stop();
    }
    fn set_volume(&mut self, volume: f64) {
        self.audio.set_volume(volume);
        self.video.change(|intent| intent.volume = volume);
    }
    fn set_muted(&mut self, muted: bool) {
        self.audio.set_muted(muted);
        self.video.change(|intent| intent.muted = muted);
    }
    fn observation(&self) -> EngineObservation {
        self.video
            .observation()
            .unwrap_or_else(|| self.audio.observation())
    }
}
