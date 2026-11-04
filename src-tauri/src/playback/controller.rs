use super::{
    contracts::{
        PlaybackCommand, PlaybackError, PlaybackItem, PlaybackSnapshot, PlaybackStatus,
        PlaybackUpdate, PlaybackVersion,
    },
    engine::{EngineObservation, PlaybackEngine},
    preferences::PlaybackPreferences,
    session::PlaybackSession,
};

struct VolumePreview {
    gesture_id: String,
    last_update: std::time::Instant,
}

// A corrupt/unsupported file must not spin the monitor thread forever.
const MAX_AUTO_ADVANCE_ATTEMPTS: usize = 3;

pub(super) struct PlaybackController<E> {
    session: PlaybackSession,
    engine: E,
    volume_preview: Option<VolumePreview>,
    auto_advance_failures: usize,
}

impl<E: PlaybackEngine> PlaybackController<E> {
    pub(super) fn new(engine: E) -> Self {
        Self {
            session: PlaybackSession::default(),
            engine,
            volume_preview: None,
            auto_advance_failures: 0,
        }
    }

    pub(super) fn snapshot(&mut self) -> PlaybackSnapshot {
        let _ = self.tick();
        self.session.snapshot()
    }

    pub(super) fn restore_preferences(
        &mut self,
        preferences: Result<PlaybackPreferences, PlaybackError>,
    ) {
        self.session.restore_preferences(preferences);
        let preferences = self.session.preferences();
        self.engine.set_volume(preferences.volume);
        self.engine.set_muted(preferences.muted);
    }

    pub(super) fn update(&mut self, known_version: PlaybackVersion) -> PlaybackUpdate {
        // Reconcile completion/failure before deciding whether a full snapshot is needed.
        let _ = self.tick();
        self.session.update(known_version)
    }

    pub(super) fn dispatch(
        &mut self,
        command: PlaybackCommand,
    ) -> Result<PlaybackSnapshot, PlaybackError> {
        self.dispatch_with_preferences(command, |_| Ok(()))
    }

    pub(super) fn dispatch_with_preferences(
        &mut self,
        command: PlaybackCommand,
        save: impl FnOnce(PlaybackPreferences) -> Result<(), PlaybackError>,
    ) -> Result<PlaybackSnapshot, PlaybackError> {
        let _ = self.tick();
        // An explicit user command is a fresh chance to recover from a bad track.
        self.auto_advance_failures = 0;

        let previous_snapshot = self.session.snapshot();
        let is_commit = matches!(command, PlaybackCommand::CommitVolumePreview { .. });
        match &command {
            PlaybackCommand::PreviewVolume {
                volume,
                generation,
                sequence,
                gesture_id,
            } => {
                Self::validate_gesture(&previous_snapshot, *generation, *sequence, gesture_id)?;
                if !volume.is_finite() || !(0.0..=100.0).contains(volume) {
                    return Err(PlaybackError::new(
                        "invalid-contract",
                        "Invalid preview volume.",
                    ));
                }
                if self
                    .volume_preview
                    .as_ref()
                    .is_some_and(|preview| preview.gesture_id != *gesture_id)
                {
                    return Err(PlaybackError::new(
                        "invalid-contract",
                        "Another volume gesture is active.",
                    ));
                }
                self.engine.set_volume(*volume);
                self.engine.set_muted(previous_snapshot.muted);
                self.volume_preview = Some(VolumePreview {
                    gesture_id: gesture_id.clone(),
                    last_update: std::time::Instant::now(),
                });
                return Ok(previous_snapshot);
            }
            PlaybackCommand::CancelVolumePreview {
                generation,
                sequence,
                gesture_id,
            } => {
                if *generation == previous_snapshot.generation
                    && *sequence == previous_snapshot.sequence
                    && self
                        .volume_preview
                        .as_ref()
                        .is_none_or(|preview| preview.gesture_id == *gesture_id)
                {
                    if self.volume_preview.is_some() {
                        self.cancel_volume_preview();
                    } else {
                        self.session.invalidate_volume_gesture();
                    }
                }
                return Ok(self.session.snapshot());
            }
            PlaybackCommand::CommitVolumePreview {
                generation,
                sequence,
                gesture_id,
                ..
            } => {
                Self::validate_gesture(&previous_snapshot, *generation, *sequence, gesture_id)?;
                if self
                    .volume_preview
                    .as_ref()
                    .is_none_or(|preview| preview.gesture_id != *gesture_id)
                {
                    return Err(PlaybackError::new(
                        "invalid-contract",
                        "The volume gesture has ended.",
                    ));
                }
            }
            _ => self.cancel_volume_preview(),
        }
        let mut candidate = self.session.clone();
        let candidate_snapshot = match candidate.dispatch(command.clone()) {
            Ok(snapshot) => snapshot,
            Err(error) => {
                if is_commit {
                    self.cancel_volume_preview();
                }
                return Err(error);
            }
        };
        if matches!(
            command,
            PlaybackCommand::SetVolume { .. }
                | PlaybackCommand::SetMuted { .. }
                | PlaybackCommand::CommitVolumePreview { .. }
        ) {
            // Keep the preview audible while saving. Failure restores the authoritative value.
            if let Err(error) = save(candidate.preferences()) {
                self.cancel_volume_preview();
                return Err(error);
            }
        }
        if is_commit {
            self.volume_preview = None;
        }
        let duration_ms = self.apply(&command, &previous_snapshot, &candidate_snapshot)?;
        if duration_ms.is_some() {
            candidate.set_duration(duration_ms);
        }

        self.session = candidate;
        self.synchronize();
        Ok(self.session.snapshot())
    }

    pub(super) fn tick(&mut self) -> Result<(), PlaybackError> {
        // A dropped frontend gesture must not leave an unsaved gain active indefinitely.
        if self.volume_preview.as_ref().is_some_and(|preview| {
            preview.last_update.elapsed() >= std::time::Duration::from_secs(2)
        }) {
            self.cancel_volume_preview();
        }
        let observation = self.synchronize();
        // Completion is owned by the engine, not by a session status flag that a
        // late decoder/device error can overwrite. Once the output ended, advance.
        if !observation.active || !observation.completed {
            return Ok(());
        }
        // A user pause/stop must hold the queue in place (and keep its engine).
        if matches!(
            self.session.snapshot().status,
            PlaybackStatus::Paused | PlaybackStatus::Stopped | PlaybackStatus::Idle
        ) {
            return Ok(());
        }
        if self.auto_advance_failures >= MAX_AUTO_ADVANCE_ATTEMPTS {
            return Ok(());
        }

        self.cancel_volume_preview();
        self.engine.prepare_for_next();
        let mut last_error: Option<PlaybackError> = None;
        for _ in self.auto_advance_failures..MAX_AUTO_ADVANCE_ATTEMPTS {
            let mut candidate = self.session.clone();
            if !candidate.advance_automatically()? {
                self.engine.stop();
                self.session = candidate;
                self.auto_advance_failures = 0;
                return Ok(());
            }

            let candidate_snapshot = candidate.snapshot();
            let item = required_current_item(&candidate_snapshot)?;
            match self.engine.load(
                item,
                0,
                true,
                candidate_snapshot.volume,
                candidate_snapshot.muted,
            ) {
                Ok(duration_ms) => {
                    candidate.set_duration(duration_ms);
                    self.session = candidate;
                    self.auto_advance_failures = 0;
                    return Ok(());
                }
                Err(error) => {
                    // Skip an unplayable item instead of parking the queue on it.
                    self.auto_advance_failures += 1;
                    self.session = candidate;
                    self.session.mark_failed();
                    self.engine.prepare_for_next();
                    last_error = Some(error);
                }
            }
        }
        Err(last_error.unwrap_or_else(|| {
            PlaybackError::new("decoder-failed", "The next track could not be loaded.")
        }))
    }

    fn validate_gesture(
        snapshot: &PlaybackSnapshot,
        generation: u64,
        sequence: u64,
        id: &str,
    ) -> Result<(), PlaybackError> {
        if id.is_empty()
            || id.len() > 64
            || generation != snapshot.generation
            || sequence != snapshot.sequence
        {
            return Err(PlaybackError::new(
                "invalid-contract",
                "The volume gesture is stale or invalid.",
            ));
        }
        Ok(())
    }

    fn cancel_volume_preview(&mut self) {
        if self.volume_preview.take().is_some() {
            self.session.invalidate_volume_gesture();
            let preferences = self.session.preferences();
            self.engine.set_volume(preferences.volume);
            self.engine.set_muted(preferences.muted);
        }
    }

    fn apply(
        &mut self,
        command: &PlaybackCommand,
        previous: &PlaybackSnapshot,
        next: &PlaybackSnapshot,
    ) -> Result<Option<u64>, PlaybackError> {
        match command {
            PlaybackCommand::PreviewVolume { .. } | PlaybackCommand::CancelVolumePreview { .. } => {
                Ok(None)
            }
            PlaybackCommand::ReplaceQueue { .. } => {
                let Some(item) = current_item(next)? else {
                    self.engine.stop();
                    return Ok(None);
                };
                self.engine.load(
                    item,
                    0,
                    next.status == PlaybackStatus::Playing,
                    next.volume,
                    next.muted,
                )
            }
            PlaybackCommand::Play => {
                let observation = self.engine.observation();
                if !observation.active || observation.completed || observation.failed {
                    let item = required_current_item(next)?;
                    self.engine
                        .load(item, next.position_ms, true, next.volume, next.muted)
                } else {
                    self.engine.set_playing(true)?;
                    Ok(None)
                }
            }
            PlaybackCommand::Pause => {
                self.engine.set_playing(false)?;
                Ok(None)
            }
            PlaybackCommand::Stop => {
                self.engine.stop();
                Ok(None)
            }
            PlaybackCommand::Seek { .. } => {
                let item = required_current_item(next)?;
                self.engine.load(
                    item,
                    next.position_ms,
                    next.status == PlaybackStatus::Playing,
                    next.volume,
                    next.muted,
                )
            }
            PlaybackCommand::Next
            | PlaybackCommand::Previous
            | PlaybackCommand::PlayIndex { .. } => {
                if next.generation == previous.generation {
                    return Ok(None);
                }
                let item = required_current_item(next)?;
                self.engine.load(item, 0, true, next.volume, next.muted)
            }
            PlaybackCommand::RemoveIndex { .. } => {
                if next.queue.is_empty() {
                    self.engine.stop();
                    return Ok(None);
                }
                if next.generation == previous.generation {
                    return Ok(None);
                }
                let item = required_current_item(next)?;
                self.engine.load(item, 0, true, next.volume, next.muted)
            }
            PlaybackCommand::Enqueue { .. } | PlaybackCommand::PlayNext { .. } => {
                if next.generation == previous.generation {
                    return Ok(None);
                }
                let item = required_current_item(next)?;
                self.engine.load(item, 0, true, next.volume, next.muted)
            }
            PlaybackCommand::RefreshItem { .. } => {
                if next.generation == previous.generation {
                    return Ok(None);
                }
                let item = required_current_item(next)?;
                self.engine.load(
                    item,
                    next.position_ms,
                    next.status == PlaybackStatus::Playing,
                    next.volume,
                    next.muted,
                )
            }
            PlaybackCommand::SetVolume { .. }
            | PlaybackCommand::SetMuted { .. }
            | PlaybackCommand::CommitVolumePreview { .. } => {
                self.engine.set_volume(next.volume);
                self.engine.set_muted(next.muted);
                Ok(None)
            }
            PlaybackCommand::SetRepeatMode { .. }
            | PlaybackCommand::SetShuffle { .. }
            | PlaybackCommand::SetPlaybackMode { .. } => Ok(None),
            PlaybackCommand::ReorderQueue { .. } => Ok(None),
        }
    }

    fn synchronize(&mut self) -> EngineObservation {
        let observation = self.engine.observation();
        if observation.active {
            self.session.sync_runtime(
                observation.position_ms,
                observation.duration_ms,
                observation.completed,
                observation.failed,
            );
        }
        observation
    }
}

fn current_item(snapshot: &PlaybackSnapshot) -> Result<Option<&PlaybackItem>, PlaybackError> {
    match snapshot.current_index {
        Some(index) => snapshot.queue.get(index).map(Some).ok_or_else(|| {
            PlaybackError::new(
                "invalid-current-index",
                "The selected item is outside the playback queue.",
            )
        }),
        None if snapshot.queue.is_empty() => Ok(None),
        None => Err(PlaybackError::new(
            "invalid-current-index",
            "A non-empty queue must select a current item.",
        )),
    }
}

fn required_current_item(snapshot: &PlaybackSnapshot) -> Result<&PlaybackItem, PlaybackError> {
    current_item(snapshot)?.ok_or_else(|| {
        PlaybackError::new(
            "empty-queue",
            "Cannot control playback while the queue is empty.",
        )
    })
}

#[cfg(test)]
mod tests {
    use std::{path::PathBuf, thread, time::Duration};

    use super::*;
    use crate::playback::contracts::{MediaKind, PlaybackStatus};
    use crate::playback::engine::NativeAudioEngine;

    #[derive(Default)]
    struct FakeEngine {
        fail_next_load: bool,
        loaded_ids: Vec<String>,
        observation: EngineObservation,
        volume: f64,
        volume_history: Vec<f64>,
        muted: bool,
    }

    #[test]
    fn preview_changes_only_output_and_respects_mute() {
        let mut controller = PlaybackController::new(FakeEngine::default());
        controller.restore_preferences(Ok(PlaybackPreferences {
            volume: 25.0,
            muted: true,
            last_audible_volume: 25.0,
        }));
        let before = controller.snapshot();
        let after = controller
            .dispatch_with_preferences(
                PlaybackCommand::PreviewVolume {
                    gesture_id: "test-gesture".to_owned(),
                    volume: 65.0,
                    generation: before.generation,
                    sequence: before.sequence,
                },
                |_| panic!("preview must not persist"),
            )
            .expect("preview");
        assert_eq!(controller.engine.volume, 65.0);
        assert!(controller.engine.muted);
        assert_eq!(after.volume, before.volume);
        assert_eq!(after.sequence, before.sequence);
        controller
            .dispatch(PlaybackCommand::CancelVolumePreview {
                gesture_id: "test-gesture".to_owned(),
                generation: before.generation,
                sequence: before.sequence,
            })
            .expect("cancel");
        assert_eq!(controller.engine.volume, 25.0);
        assert!(controller.engine.muted);
    }

    #[test]
    fn preview_expires_and_rejects_invalid_or_stale_input() {
        let mut controller = PlaybackController::new(FakeEngine::default());
        controller.restore_preferences(Ok(PlaybackPreferences::default()));
        let before = controller.snapshot();
        for (volume, sequence) in [
            (f64::NAN, before.sequence),
            (101.0, before.sequence),
            (30.0, before.sequence + 1),
        ] {
            assert!(controller
                .dispatch(PlaybackCommand::PreviewVolume {
                    gesture_id: "test-gesture".to_owned(),
                    volume,
                    generation: before.generation,
                    sequence,
                })
                .is_err());
        }
        controller
            .dispatch(PlaybackCommand::PreviewVolume {
                gesture_id: "test-gesture".to_owned(),
                volume: 30.0,
                generation: before.generation,
                sequence: before.sequence,
            })
            .expect("preview");
        controller.volume_preview = Some(VolumePreview {
            gesture_id: "test-gesture".to_owned(),
            last_update: std::time::Instant::now() - Duration::from_secs(3),
        });
        controller.tick().expect("expiry");
        assert_eq!(controller.engine.volume, before.volume);
        assert!(controller.volume_preview.is_none());
    }

    #[test]
    fn failed_commit_restores_saved_output_after_preview() {
        let mut controller = PlaybackController::new(FakeEngine::default());
        controller.restore_preferences(Ok(PlaybackPreferences::default()));
        let before = controller.snapshot();
        controller
            .dispatch(PlaybackCommand::PreviewVolume {
                gesture_id: "test-gesture".to_owned(),
                volume: 30.0,
                generation: before.generation,
                sequence: before.sequence,
            })
            .expect("preview");
        assert!(controller
            .dispatch_with_preferences(
                PlaybackCommand::CommitVolumePreview {
                    volume: 30.0,
                    generation: before.generation,
                    sequence: before.sequence,
                    gesture_id: "test-gesture".to_owned(),
                },
                |_| { Err(PlaybackError::new("preferences-unavailable", "fixture")) }
            )
            .is_err());
        assert_eq!(controller.engine.volume, before.volume);
        assert_eq!(controller.snapshot().volume, before.volume);
        assert!(controller.volume_preview.is_none());
    }

    #[test]
    fn mute_command_cancels_preview_and_late_preview_cannot_override_it() {
        let mut controller = PlaybackController::new(FakeEngine::default());
        controller.restore_preferences(Ok(PlaybackPreferences::default()));
        let before = controller.snapshot();
        let command = PlaybackCommand::PreviewVolume {
            gesture_id: "test-gesture".to_owned(),
            volume: 30.0,
            generation: before.generation,
            sequence: before.sequence,
        };
        controller.dispatch(command.clone()).expect("preview");
        controller
            .dispatch(PlaybackCommand::SetMuted { muted: true })
            .expect("mute");
        assert!(controller.dispatch(command).is_err());
        assert!(controller.engine.muted);
        assert_eq!(controller.engine.volume, before.volume);
    }

    #[test]
    fn commit_preserves_mute_saves_once_and_does_not_restore_old_gain() {
        let mut controller = PlaybackController::new(FakeEngine::default());
        controller.restore_preferences(Ok(PlaybackPreferences {
            volume: 25.0,
            muted: true,
            last_audible_volume: 25.0,
        }));
        let before = controller.snapshot();
        controller
            .dispatch(PlaybackCommand::PreviewVolume {
                volume: 60.0,
                generation: before.generation,
                sequence: before.sequence,
                gesture_id: "owner".to_owned(),
            })
            .unwrap();
        let commit = PlaybackCommand::CommitVolumePreview {
            volume: 60.0,
            generation: before.generation,
            sequence: before.sequence,
            gesture_id: "owner".to_owned(),
        };
        let mut saves = 0;
        let after = controller
            .dispatch_with_preferences(commit.clone(), |preferences| {
                saves += 1;
                assert_eq!(preferences.volume, 60.0);
                assert!(preferences.muted);
                Ok(())
            })
            .unwrap();
        assert_eq!(saves, 1);
        assert_eq!(after.volume, 60.0);
        assert!(after.muted);
        assert_eq!(controller.engine.volume_history, vec![25.0, 60.0, 60.0]);
        assert!(controller
            .dispatch_with_preferences(commit, |_| panic!("duplicate save"))
            .is_err());
    }

    #[test]
    fn cancellation_and_expiry_reject_late_renewal_and_commit() {
        for expired in [false, true] {
            let mut controller = PlaybackController::new(FakeEngine::default());
            let before = controller.snapshot();
            let preview = PlaybackCommand::PreviewVolume {
                volume: 30.0,
                generation: before.generation,
                sequence: before.sequence,
                gesture_id: "owner".to_owned(),
            };
            controller.dispatch(preview.clone()).unwrap();
            if expired {
                controller.volume_preview.as_mut().unwrap().last_update =
                    std::time::Instant::now() - Duration::from_secs(3);
                controller.tick().unwrap();
            } else {
                controller
                    .dispatch(PlaybackCommand::CancelVolumePreview {
                        generation: before.generation,
                        sequence: before.sequence,
                        gesture_id: "owner".to_owned(),
                    })
                    .unwrap();
            }
            assert!(controller.dispatch(preview).is_err());
            assert!(controller
                .dispatch_with_preferences(
                    PlaybackCommand::CommitVolumePreview {
                        volume: 30.0,
                        generation: before.generation,
                        sequence: before.sequence,
                        gesture_id: "owner".to_owned(),
                    },
                    |_| panic!("stale save")
                )
                .is_err());
            assert_eq!(controller.engine.volume, before.volume);
            assert!(controller.snapshot().sequence > before.sequence);
        }
    }

    #[test]
    fn other_gesture_cannot_cancel_or_commit_active_preview() {
        let mut controller = PlaybackController::new(FakeEngine::default());
        let before = controller.snapshot();
        controller
            .dispatch(PlaybackCommand::PreviewVolume {
                volume: 30.0,
                generation: before.generation,
                sequence: before.sequence,
                gesture_id: "owner".to_owned(),
            })
            .unwrap();
        controller
            .dispatch(PlaybackCommand::CancelVolumePreview {
                generation: before.generation,
                sequence: before.sequence,
                gesture_id: "other".to_owned(),
            })
            .unwrap();
        assert!(controller
            .dispatch_with_preferences(
                PlaybackCommand::CommitVolumePreview {
                    volume: 10.0,
                    generation: before.generation,
                    sequence: before.sequence,
                    gesture_id: "other".to_owned(),
                },
                |_| panic!("foreign save")
            )
            .is_err());
        assert_eq!(controller.engine.volume, 30.0);
        assert_eq!(controller.snapshot().sequence, before.sequence);
    }

    impl PlaybackEngine for FakeEngine {
        fn load(
            &mut self,
            item: &PlaybackItem,
            position_ms: u64,
            _playing: bool,
            volume: f64,
            muted: bool,
        ) -> Result<Option<u64>, PlaybackError> {
            if self.fail_next_load {
                self.fail_next_load = false;
                return Err(PlaybackError::new("decoder-failed", "test failure"));
            }
            self.loaded_ids.push(item.id.clone());
            self.volume = volume;
            self.muted = muted;
            self.observation = EngineObservation {
                active: true,
                position_ms,
                duration_ms: Some(60_000),
                completed: false,
                failed: false,
            };
            Ok(Some(60_000))
        }

        fn set_playing(&mut self, _playing: bool) -> Result<(), PlaybackError> {
            if self.observation.active {
                Ok(())
            } else {
                Err(PlaybackError::new("playback-unavailable", "test failure"))
            }
        }

        fn stop(&mut self) {
            self.observation = EngineObservation::default();
        }

        fn set_volume(&mut self, volume: f64) {
            self.volume = volume;
            self.volume_history.push(volume);
        }

        fn set_muted(&mut self, muted: bool) {
            self.muted = muted;
        }

        fn observation(&self) -> EngineObservation {
            self.observation
        }
    }

    fn track(id: &str) -> PlaybackItem {
        PlaybackItem {
            id: id.to_owned(),
            path: format!(r"C:\Music\{id}.flac"),
            title: id.to_owned(),
            kind: MediaKind::Audio,
            duration_ms: None,
        }
    }

    #[test]
    fn restored_preferences_apply_before_the_first_audio_load() {
        let mut controller = PlaybackController::new(FakeEngine::default());
        controller.restore_preferences(Ok(PlaybackPreferences {
            volume: 27.0,
            muted: true,
            last_audible_volume: 27.0,
        }));
        controller
            .dispatch(PlaybackCommand::ReplaceQueue {
                queue: vec![track("one")],
                current_index: Some(0),
                autoplay: true,
            })
            .expect("load restored session");
        assert_eq!(controller.engine.volume, 27.0);
        assert!(controller.engine.muted);
        assert!(controller.snapshot().preferences_error.is_none());
    }

    #[test]
    fn failed_audio_preference_write_keeps_live_output_and_session_unchanged() {
        let mut controller = PlaybackController::new(FakeEngine::default());
        controller.restore_preferences(Ok(PlaybackPreferences::default()));
        let before = controller.snapshot();
        let result = controller.dispatch_with_preferences(
            PlaybackCommand::SetVolume { volume: 31.0 },
            |_| {
                Err(PlaybackError::new(
                    "preferences-unavailable",
                    "write failed",
                ))
            },
        );
        assert!(result.is_err());
        assert_eq!(controller.engine.volume, before.volume);
        assert_eq!(controller.engine.muted, before.muted);
        assert_eq!(controller.snapshot().sequence, before.sequence);
        assert_eq!(controller.snapshot().volume, before.volume);
    }

    #[test]
    fn volume_and_mute_commit_the_same_preferences_to_output_and_storage() {
        let mut controller = PlaybackController::new(FakeEngine::default());
        let mut saved = Vec::new();
        for command in [
            PlaybackCommand::SetVolume { volume: 47.0 },
            PlaybackCommand::SetVolume { volume: 0.0 },
            PlaybackCommand::SetMuted { muted: false },
        ] {
            controller
                .dispatch_with_preferences(command, |preferences| {
                    saved.push(preferences);
                    Ok(())
                })
                .expect("save and apply");
        }
        assert_eq!(saved.len(), 3);
        assert_eq!(saved[1].volume, 0.0);
        assert!(saved[1].muted);
        assert_eq!(saved[2].volume, 47.0);
        assert_eq!(controller.engine.volume, saved[2].volume);
        assert_eq!(controller.engine.muted, saved[2].muted);
    }

    #[test]
    fn invalid_volume_and_unrelated_commands_do_not_write_preferences() {
        let mut controller = PlaybackController::new(FakeEngine::default());
        let mut writes = 0;
        assert!(controller
            .dispatch_with_preferences(PlaybackCommand::SetVolume { volume: 101.0 }, |_| {
                writes += 1;
                Ok(())
            })
            .is_err());
        controller
            .dispatch_with_preferences(PlaybackCommand::SetShuffle { shuffle: true }, |_| {
                writes += 1;
                Ok(())
            })
            .expect("shuffle");
        assert_eq!(writes, 0);
    }

    #[test]
    fn engine_failure_does_not_commit_the_candidate_session() {
        let mut controller = PlaybackController::new(FakeEngine {
            fail_next_load: true,
            ..FakeEngine::default()
        });

        let result = controller.dispatch(PlaybackCommand::ReplaceQueue {
            queue: vec![track("one")],
            current_index: Some(0),
            autoplay: true,
        });

        assert_eq!(result.expect_err("load should fail").code, "decoder-failed");
        let snapshot = controller.snapshot();
        assert_eq!(snapshot.generation, 0);
        assert!(snapshot.queue.is_empty());
        assert_eq!(snapshot.status, PlaybackStatus::Idle);
    }

    #[test]
    fn conditional_reads_reconcile_automatic_next_before_comparing_versions() {
        let mut controller = PlaybackController::new(FakeEngine::default());
        let previous = controller
            .dispatch(PlaybackCommand::ReplaceQueue {
                queue: vec![track("one"), track("two")],
                current_index: Some(0),
                autoplay: true,
            })
            .expect("load");
        controller.engine.observation.completed = true;
        controller.engine.observation.position_ms = 60_000;
        let PlaybackUpdate::Snapshot { snapshot } = controller.update(PlaybackVersion {
            generation: previous.generation,
            sequence: previous.sequence,
        }) else {
            panic!("automatic next must supply its new queue state");
        };
        assert_eq!(snapshot.current_index, Some(1));
        assert_eq!(snapshot.status, PlaybackStatus::Playing);
        assert_eq!(snapshot.generation, previous.generation + 1);
        assert_eq!(snapshot.position_ms, 0);
    }

    #[test]
    fn conditional_reads_skip_an_unplayable_next_track_instead_of_parking() {
        let mut controller = PlaybackController::new(FakeEngine::default());
        let previous = controller
            .dispatch(PlaybackCommand::ReplaceQueue {
                queue: vec![track("one"), track("two")],
                current_index: Some(0),
                autoplay: true,
            })
            .expect("load");
        controller.engine.observation.completed = true;
        controller.engine.fail_next_load = true;
        let PlaybackUpdate::Snapshot { snapshot } = controller.update(PlaybackVersion {
            generation: previous.generation,
            sequence: previous.sequence,
        }) else {
            panic!("skipping must supply its complete state");
        };
        // Index 1 could not load, so the monitor moved on to the following item
        // (index 0 in this two-track loop) instead of parking on the bad track.
        assert_eq!(snapshot.status, PlaybackStatus::Playing);
        assert_eq!(snapshot.current_index, Some(0));
        assert!(snapshot.generation > previous.generation + 1);
        assert_eq!(controller.engine.loaded_ids, ["one", "one"]);
    }

    #[test]
    fn a_legacy_stop_at_end_mode_still_restarts_the_single_track() {
        let mut controller = PlaybackController::new(FakeEngine::default());
        controller
            .dispatch(PlaybackCommand::ReplaceQueue {
                queue: vec![track("one")],
                current_index: Some(0),
                autoplay: true,
            })
            .expect("load");
        let previous = controller
            .dispatch(PlaybackCommand::SetRepeatMode {
                repeat_mode: crate::playback::contracts::RepeatMode::None,
            })
            .expect("mode");
        controller.engine.observation.completed = true;
        controller.engine.observation.position_ms = 60_000;
        let PlaybackUpdate::Snapshot { snapshot } = controller.update(PlaybackVersion {
            generation: previous.generation,
            sequence: previous.sequence,
        }) else {
            panic!("the loop must supply its complete state");
        };
        assert_eq!(snapshot.status, PlaybackStatus::Playing);
        assert_eq!(snapshot.position_ms, 0);
        assert_eq!(controller.engine.loaded_ids, ["one", "one"]);
    }

    #[test]
    fn a_late_engine_error_after_the_audible_tail_still_advances() {
        let mut controller = PlaybackController::new(FakeEngine::default());
        controller
            .dispatch(PlaybackCommand::ReplaceQueue {
                queue: vec![track("one"), track("two")],
                current_index: Some(0),
                autoplay: true,
            })
            .expect("load should work");
        controller.engine.observation.position_ms = 60_000;
        controller.engine.observation.completed = true;
        controller.engine.observation.failed = true;

        controller.tick().expect("automatic advance should work");

        let snapshot = controller.session.snapshot();
        assert_eq!(snapshot.status, PlaybackStatus::Playing);
        assert_eq!(snapshot.current_index, Some(1));
        assert_eq!(controller.engine.loaded_ids, ["one", "two"]);
    }

    #[test]
    fn completion_advances_to_the_next_item_without_a_webview_event() {
        let mut controller = PlaybackController::new(FakeEngine::default());
        controller
            .dispatch(PlaybackCommand::ReplaceQueue {
                queue: vec![track("one"), track("two")],
                current_index: Some(0),
                autoplay: true,
            })
            .expect("load should work");
        controller.engine.observation.position_ms = 60_000;
        controller.engine.observation.completed = true;

        controller.tick().expect("automatic advance should work");
        let snapshot = controller.session.snapshot();

        assert_eq!(snapshot.current_index, Some(1));
        assert_eq!(snapshot.generation, 2);
        assert_eq!(snapshot.status, PlaybackStatus::Playing);
        assert_eq!(controller.engine.loaded_ids, ["one", "two"]);
    }

    #[test]
    fn removing_the_current_item_is_transactional_when_the_next_load_fails() {
        let mut controller = PlaybackController::new(FakeEngine::default());
        controller
            .dispatch(PlaybackCommand::ReplaceQueue {
                queue: vec![track("one"), track("two")],
                current_index: Some(0),
                autoplay: true,
            })
            .expect("initial load should work");
        controller.engine.fail_next_load = true;

        let error = controller
            .dispatch(PlaybackCommand::RemoveIndex { index: 0 })
            .expect_err("replacement load should fail");
        let snapshot = controller.session.snapshot();

        assert_eq!(error.code, "decoder-failed");
        assert_eq!(snapshot.queue.len(), 2);
        assert_eq!(snapshot.current_index, Some(0));
        assert_eq!(snapshot.queue[0].id, "one");
    }

    #[test]
    fn reordering_does_not_reload_the_active_engine_item() {
        let mut controller = PlaybackController::new(FakeEngine::default());
        controller
            .dispatch(PlaybackCommand::ReplaceQueue {
                queue: vec![track("one"), track("two"), track("three")],
                current_index: Some(1),
                autoplay: true,
            })
            .expect("initial load should work");
        let generation = controller.session.snapshot().generation;

        let snapshot = controller
            .dispatch(PlaybackCommand::ReorderQueue {
                from_index: 0,
                to_index: 2,
            })
            .expect("reorder should work");

        assert_eq!(controller.engine.loaded_ids, ["two"]);
        assert_eq!(snapshot.current_index, Some(0));
        assert_eq!(snapshot.queue[0].id, "two");
        assert_eq!(snapshot.generation, generation);
    }

    #[test]
    fn enqueue_only_loads_the_engine_when_the_queue_was_empty() {
        let mut controller = PlaybackController::new(FakeEngine::default());

        controller
            .dispatch(PlaybackCommand::Enqueue {
                items: vec![track("one")],
            })
            .expect("empty enqueue should load");
        controller
            .dispatch(PlaybackCommand::Enqueue {
                items: vec![track("two")],
            })
            .expect("non-empty enqueue should append");

        assert_eq!(controller.engine.loaded_ids, ["one"]);
        assert_eq!(controller.session.snapshot().queue.len(), 2);
    }

    #[test]
    fn refreshing_only_reloads_the_engine_for_the_current_item() {
        let mut controller = PlaybackController::new(FakeEngine::default());
        controller
            .dispatch(PlaybackCommand::ReplaceQueue {
                queue: vec![track("one"), track("two")],
                current_index: Some(0),
                autoplay: true,
            })
            .expect("initial load");
        let mut queued_replacement = track("two");
        queued_replacement.path = r"D:\Recovered\two.flac".to_owned();
        controller
            .dispatch(PlaybackCommand::RefreshItem {
                item: queued_replacement,
            })
            .expect("queued refresh");
        assert_eq!(controller.engine.loaded_ids, ["one"]);

        let mut current_replacement = track("one");
        current_replacement.path = r"D:\Recovered\one.flac".to_owned();
        controller
            .dispatch(PlaybackCommand::RefreshItem {
                item: current_replacement,
            })
            .expect("current refresh");
        assert_eq!(controller.engine.loaded_ids, ["one", "one"]);
        assert_eq!(
            controller.session.snapshot().queue[0].path,
            r"D:\Recovered\one.flac"
        );
    }

    #[test]
    #[ignore = "requires a Windows audio device and the generated media fixtures"]
    fn production_engine_advances_between_two_generated_files() {
        let fixtures = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("..")
            .join("spikes")
            .join("media-fixtures")
            .join("generated");
        let fixture_track = |filename: &str| PlaybackItem {
            id: filename.to_owned(),
            path: fixtures.join(filename).to_string_lossy().into_owned(),
            title: filename.to_owned(),
            kind: MediaKind::Audio,
            duration_ms: None,
        };
        let queue = vec![
            fixture_track("tone.wav"),
            fixture_track("tone-44100-mono.wav"),
        ];
        assert!(queue.iter().all(|item| PathBuf::from(&item.path).is_file()));

        let mut controller = PlaybackController::new(NativeAudioEngine::default());
        controller
            .dispatch(PlaybackCommand::SetRepeatMode {
                repeat_mode: crate::playback::contracts::RepeatMode::None,
            })
            .expect("mode should work");
        controller
            .dispatch(PlaybackCommand::SetMuted { muted: true })
            .expect("mute should work");
        controller
            .dispatch(PlaybackCommand::ReplaceQueue {
                queue,
                current_index: Some(0),
                autoplay: true,
            })
            .expect("production queue should load");

        for _ in 0..500 {
            controller
                .tick()
                .expect("production queue tick should work");
            let snapshot = controller.session.snapshot();
            if snapshot.current_index == Some(1) {
                assert_eq!(snapshot.status, PlaybackStatus::Playing);
                controller
                    .dispatch(PlaybackCommand::Stop)
                    .expect("queue should stop cleanly");
                return;
            }
            thread::sleep(Duration::from_millis(10));
        }

        panic!("production engine did not advance within five seconds");
    }
}
