mod hybrid;
mod native;
mod pcm;

use super::contracts::{PlaybackError, PlaybackItem};

pub(super) use hybrid::HybridEngine;
pub(super) use native::NativeAudioEngine;

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub(super) struct EngineObservation {
    pub active: bool,
    pub position_ms: u64,
    pub duration_ms: Option<u64>,
    pub completed: bool,
    pub failed: bool,
}

pub(super) trait PlaybackEngine {
    fn load(
        &mut self,
        item: &PlaybackItem,
        position_ms: u64,
        playing: bool,
        volume: f64,
        muted: bool,
    ) -> Result<Option<u64>, PlaybackError>;

    fn set_playing(&mut self, playing: bool) -> Result<(), PlaybackError>;
    /// Release the finishing output before the automatic advance loads the next item.
    /// The monitor thread has no WebView acknowledgement, so this must not depend on one.
    fn prepare_for_next(&mut self) {}
    fn stop(&mut self);
    fn set_volume(&mut self, volume: f64);
    fn set_muted(&mut self, muted: bool);
    fn observation(&self) -> EngineObservation;
}
