use std::collections::HashSet;

use super::{
    contracts::{
        PlaybackCommand, PlaybackError, PlaybackPosition, PlaybackSnapshot, PlaybackStatus,
        PlaybackUpdate, PlaybackVersion, RepeatMode,
    },
    order::{OrderMove, PlaybackOrder},
    preferences::PlaybackPreferences,
};

#[derive(Clone, Debug)]
pub struct PlaybackSession {
    snapshot: PlaybackSnapshot,
    order: PlaybackOrder,
    last_audible_volume: f64,
}

impl Default for PlaybackSession {
    fn default() -> Self {
        Self {
            snapshot: PlaybackSnapshot {
                generation: 0,
                sequence: 0,
                status: PlaybackStatus::Idle,
                queue: Vec::new(),
                current_index: None,
                position_ms: 0,
                duration_ms: None,
                volume: 100.0,
                muted: false,
                repeat_mode: RepeatMode::All,
                shuffle: false,
                preferences_error: None,
            },
            order: PlaybackOrder::build(0, 0, false),
            last_audible_volume: 100.0,
        }
    }
}

impl PlaybackSession {
    pub(super) fn restore_preferences(
        &mut self,
        restored: Result<PlaybackPreferences, PlaybackError>,
    ) {
        let (preferences, error) = match restored.and_then(PlaybackPreferences::validate) {
            Ok(value) => (value, None),
            Err(error) => (PlaybackPreferences::muted_fallback(), Some(error)),
        };
        self.snapshot.volume = preferences.volume;
        self.snapshot.muted = preferences.muted;
        self.last_audible_volume = preferences.last_audible_volume;
        self.snapshot.preferences_error = error;
    }

    pub(super) fn preferences(&self) -> PlaybackPreferences {
        PlaybackPreferences {
            volume: self.snapshot.volume,
            muted: self.snapshot.muted,
            last_audible_volume: self.last_audible_volume,
        }
    }

    pub fn snapshot(&self) -> PlaybackSnapshot {
        self.snapshot.clone()
    }

    pub(super) fn invalidate_volume_gesture(&mut self) {
        self.bump_sequence();
    }

    pub fn update(&self, known_version: PlaybackVersion) -> PlaybackUpdate {
        let snapshot = &self.snapshot;
        if known_version.generation != snapshot.generation
            || known_version.sequence != snapshot.sequence
        {
            return PlaybackUpdate::Snapshot {
                snapshot: self.snapshot(),
            };
        }
        PlaybackUpdate::Position {
            position: PlaybackPosition {
                generation: snapshot.generation,
                sequence: snapshot.sequence,
                status: snapshot.status,
                media_id: snapshot
                    .current_index
                    .and_then(|index| snapshot.queue.get(index))
                    .map(|item| item.id.clone()),
                position_ms: snapshot.position_ms,
                duration_ms: snapshot.duration_ms,
            },
        }
    }

    pub fn dispatch(
        &mut self,
        command: PlaybackCommand,
    ) -> Result<PlaybackSnapshot, PlaybackError> {
        match command {
            PlaybackCommand::ReplaceQueue {
                queue,
                current_index,
                autoplay,
            } => self.replace_queue(queue, current_index, autoplay)?,
            PlaybackCommand::Play => {
                self.require_queue()?;
                if self.snapshot.status == PlaybackStatus::Completed {
                    self.snapshot.position_ms = 0;
                }
                self.snapshot.status = PlaybackStatus::Playing;
                self.bump_sequence();
            }
            PlaybackCommand::Pause => {
                self.require_queue()?;
                self.snapshot.status = PlaybackStatus::Paused;
                self.bump_sequence();
            }
            PlaybackCommand::Stop => {
                self.require_queue()?;
                self.snapshot.status = PlaybackStatus::Stopped;
                self.snapshot.position_ms = 0;
                self.bump_sequence();
            }
            PlaybackCommand::Seek { position_ms } => {
                self.require_queue()?;
                self.snapshot.position_ms = self
                    .snapshot
                    .duration_ms
                    .map_or(position_ms, |duration| position_ms.min(duration));
                if self.snapshot.status == PlaybackStatus::Completed {
                    self.snapshot.status = PlaybackStatus::Paused;
                }
                self.bump_sequence();
            }
            PlaybackCommand::Next => {
                self.advance_next(false)?;
            }
            PlaybackCommand::Previous => self.advance_previous()?,
            PlaybackCommand::PlayIndex { index } => {
                self.require_index(index)?;
                self.order =
                    PlaybackOrder::build(self.snapshot.queue.len(), index, self.snapshot.shuffle);
                self.load_index(index);
            }
            PlaybackCommand::RemoveIndex { index } => {
                self.remove_index(index)?;
            }
            PlaybackCommand::ReorderQueue {
                from_index,
                to_index,
            } => {
                self.reorder_queue(from_index, to_index)?;
            }
            PlaybackCommand::RefreshItem { item } => {
                self.refresh_item(item)?;
            }
            PlaybackCommand::Enqueue { items } => {
                self.add_items(items, false)?;
            }
            PlaybackCommand::PlayNext { items } => {
                self.add_items(items, true)?;
            }
            PlaybackCommand::PreviewVolume { .. } | PlaybackCommand::CancelVolumePreview { .. } => {
                return Err(PlaybackError::new(
                    "invalid-contract",
                    "Preview belongs to the output controller.",
                ));
            }
            PlaybackCommand::SetVolume { volume }
            | PlaybackCommand::CommitVolumePreview { volume, .. } => {
                let keep_muted = matches!(command, PlaybackCommand::CommitVolumePreview { .. })
                    && self.snapshot.muted;
                if !volume.is_finite() || !(0.0..=100.0).contains(&volume) {
                    return Err(PlaybackError::new(
                        "invalid-contract",
                        "Volume must be a finite number between 0 and 100.",
                    ));
                }
                self.snapshot.volume = volume;
                self.snapshot.muted = keep_muted || volume == 0.0;
                if volume > 0.0 {
                    self.last_audible_volume = volume.max(1.0);
                }
                self.snapshot.preferences_error = None;
                self.bump_sequence();
            }
            PlaybackCommand::SetMuted { muted } => {
                if !muted && self.snapshot.volume == 0.0 {
                    self.snapshot.volume = self.last_audible_volume;
                }
                self.snapshot.muted = muted;
                self.snapshot.preferences_error = None;
                self.bump_sequence();
            }
            PlaybackCommand::SetRepeatMode { repeat_mode } => {
                self.snapshot.repeat_mode = repeat_mode;
                self.snapshot.shuffle = false;
                self.rebuild_order();
                self.bump_sequence();
            }
            PlaybackCommand::SetShuffle { shuffle } => {
                self.snapshot.shuffle = shuffle;
                if shuffle {
                    self.snapshot.repeat_mode = RepeatMode::All;
                }
                self.rebuild_order();
                self.bump_sequence();
            }
        }

        Ok(self.snapshot())
    }

    pub fn advance_automatically(&mut self) -> Result<bool, PlaybackError> {
        self.require_queue()?;
        if self.snapshot.status != PlaybackStatus::Completed {
            return Ok(false);
        }
        self.advance_next(true)
    }

    pub fn set_duration(&mut self, duration_ms: Option<u64>) {
        self.snapshot.duration_ms = duration_ms.or(self.snapshot.duration_ms);
        if let Some(duration) = self.snapshot.duration_ms {
            self.snapshot.position_ms = self.snapshot.position_ms.min(duration);
        }
    }

    pub fn sync_runtime(
        &mut self,
        position_ms: u64,
        duration_ms: Option<u64>,
        completed: bool,
        failed: bool,
    ) {
        if self.snapshot.queue.is_empty() {
            return;
        }

        self.set_duration(duration_ms);
        self.snapshot.position_ms = self
            .snapshot
            .duration_ms
            .map_or(position_ms, |duration| position_ms.min(duration));

        let next_status = if failed {
            Some(PlaybackStatus::Failed)
        } else if completed && self.snapshot.status == PlaybackStatus::Playing {
            Some(PlaybackStatus::Completed)
        } else {
            None
        };
        if let Some(status) = next_status {
            if self.snapshot.status != status {
                self.snapshot.status = status;
                self.bump_sequence();
            }
        }
    }

    pub fn mark_failed(&mut self) {
        if self.snapshot.status != PlaybackStatus::Failed {
            self.snapshot.status = PlaybackStatus::Failed;
            self.bump_sequence();
        }
    }

    fn replace_queue(
        &mut self,
        queue: Vec<super::contracts::PlaybackItem>,
        current_index: Option<usize>,
        autoplay: bool,
    ) -> Result<(), PlaybackError> {
        validate_queue_items(&queue)?;
        let valid_current = current_index.is_some_and(|index| index < queue.len());
        let valid_empty_queue = queue.is_empty() && current_index.is_none();
        if !valid_current && !valid_empty_queue {
            return Err(PlaybackError::new(
                "invalid-current-index",
                "The selected item is outside the playback queue.",
            ));
        }

        let mut paths = HashSet::with_capacity(queue.len());
        if queue
            .iter()
            .any(|item| !paths.insert(queue_path_key(&item.path)))
        {
            return Err(PlaybackError::new(
                "duplicate-queue-item",
                "The playback queue cannot contain the same local path twice.",
            ));
        }

        self.snapshot.generation = self.snapshot.generation.saturating_add(1);
        self.snapshot.sequence = 0;
        self.snapshot.queue = queue;
        self.snapshot.current_index = current_index;
        self.snapshot.position_ms = 0;
        self.snapshot.duration_ms = current_index.and_then(|index| {
            self.snapshot
                .queue
                .get(index)
                .and_then(|item| item.duration_ms)
        });
        self.snapshot.status = if self.snapshot.queue.is_empty() {
            PlaybackStatus::Idle
        } else if autoplay {
            PlaybackStatus::Playing
        } else {
            PlaybackStatus::Paused
        };
        self.order = PlaybackOrder::build(
            self.snapshot.queue.len(),
            current_index.unwrap_or(0),
            self.snapshot.shuffle,
        );
        Ok(())
    }

    fn advance_next(&mut self, automatic: bool) -> Result<bool, PlaybackError> {
        self.require_queue()?;
        let repeat_mode = if !automatic && self.snapshot.repeat_mode == RepeatMode::One {
            RepeatMode::All
        } else {
            self.snapshot.repeat_mode
        };
        match self.order.next(repeat_mode) {
            OrderMove::Stop => Ok(false),
            OrderMove::Play { order, index } => {
                self.order = order;
                self.load_index(index);
                Ok(true)
            }
        }
    }

    fn advance_previous(&mut self) -> Result<(), PlaybackError> {
        self.require_queue()?;
        let repeat_mode = if self.snapshot.repeat_mode == RepeatMode::One {
            RepeatMode::All
        } else {
            self.snapshot.repeat_mode
        };
        if let OrderMove::Play { order, index } = self.order.previous(repeat_mode) {
            self.order = order;
            self.load_index(index);
        }
        Ok(())
    }

    fn load_index(&mut self, index: usize) {
        self.snapshot.generation = self.snapshot.generation.saturating_add(1);
        self.snapshot.sequence = 0;
        self.snapshot.current_index = Some(index);
        self.snapshot.position_ms = 0;
        self.snapshot.duration_ms = self.snapshot.queue[index].duration_ms;
        self.snapshot.status = PlaybackStatus::Playing;
    }

    fn rebuild_order(&mut self) {
        self.order = PlaybackOrder::build(
            self.snapshot.queue.len(),
            self.snapshot.current_index.unwrap_or(0),
            self.snapshot.shuffle,
        );
    }

    fn refresh_item(&mut self, item: super::contracts::PlaybackItem) -> Result<(), PlaybackError> {
        validate_queue_items(std::slice::from_ref(&item))?;
        let Some(index) = self
            .snapshot
            .queue
            .iter()
            .position(|candidate| candidate.id == item.id)
        else {
            return Ok(());
        };
        let replacement_path = queue_path_key(&item.path);
        if self
            .snapshot
            .queue
            .iter()
            .enumerate()
            .any(|(candidate_index, candidate)| {
                candidate_index != index && queue_path_key(&candidate.path) == replacement_path
            })
        {
            return Err(PlaybackError::new(
                "duplicate-queue-item",
                "The replacement path already exists in the playback queue.",
            ));
        }

        let duration_ms = item.duration_ms;
        self.snapshot.queue[index] = item;
        if self.snapshot.current_index == Some(index) {
            self.snapshot.generation = self.snapshot.generation.saturating_add(1);
            self.snapshot.sequence = 0;
            self.snapshot.duration_ms = duration_ms;
            if let Some(duration) = duration_ms {
                self.snapshot.position_ms = self.snapshot.position_ms.min(duration);
            }
            if self.snapshot.status == PlaybackStatus::Failed {
                self.snapshot.status = PlaybackStatus::Paused;
            }
        } else {
            self.bump_sequence();
        }
        Ok(())
    }

    fn remove_index(&mut self, index: usize) -> Result<(), PlaybackError> {
        self.require_index(index)?;
        let current_index = self.snapshot.current_index.ok_or_else(|| {
            PlaybackError::new(
                "invalid-current-index",
                "A non-empty queue must select a current item.",
            )
        })?;
        self.snapshot.queue.remove(index);

        if self.snapshot.queue.is_empty() {
            self.snapshot.generation = self.snapshot.generation.saturating_add(1);
            self.snapshot.sequence = 0;
            self.snapshot.current_index = None;
            self.snapshot.position_ms = 0;
            self.snapshot.duration_ms = None;
            self.snapshot.status = PlaybackStatus::Idle;
            self.order = PlaybackOrder::build(0, 0, false);
            return Ok(());
        }

        if index == current_index {
            let next_index = index.min(self.snapshot.queue.len() - 1);
            self.order =
                PlaybackOrder::build(self.snapshot.queue.len(), next_index, self.snapshot.shuffle);
            self.load_index(next_index);
            return Ok(());
        }

        let adjusted_index = if index < current_index {
            current_index - 1
        } else {
            current_index
        };
        self.snapshot.current_index = Some(adjusted_index);
        self.rebuild_order();
        self.bump_sequence();
        Ok(())
    }

    fn reorder_queue(&mut self, from_index: usize, to_index: usize) -> Result<(), PlaybackError> {
        self.require_index(from_index)?;
        self.require_index(to_index)?;
        if from_index == to_index {
            return Ok(());
        }

        let current_index = self.snapshot.current_index.ok_or_else(|| {
            PlaybackError::new(
                "invalid-current-index",
                "A non-empty queue must select a current item.",
            )
        })?;
        let item = self.snapshot.queue.remove(from_index);
        self.snapshot.queue.insert(to_index, item);
        let adjusted_current = if current_index == from_index {
            to_index
        } else if from_index < current_index && to_index >= current_index {
            current_index - 1
        } else if from_index > current_index && to_index <= current_index {
            current_index + 1
        } else {
            current_index
        };
        self.snapshot.current_index = Some(adjusted_current);
        self.rebuild_order();
        self.bump_sequence();
        Ok(())
    }

    fn add_items(
        &mut self,
        items: Vec<super::contracts::PlaybackItem>,
        play_next: bool,
    ) -> Result<(), PlaybackError> {
        if items.is_empty() {
            return Err(PlaybackError::new(
                "invalid-contract",
                "At least one media item is required for a queue insertion.",
            ));
        }
        validate_queue_items(&items)?;

        let mut paths = self
            .snapshot
            .queue
            .iter()
            .map(|item| queue_path_key(&item.path))
            .collect::<HashSet<_>>();
        let additions = items
            .into_iter()
            .filter(|item| paths.insert(queue_path_key(&item.path)))
            .collect::<Vec<_>>();
        if additions.is_empty() {
            return Ok(());
        }

        if self.snapshot.queue.is_empty() {
            return self.replace_queue(additions, Some(0), true);
        }

        let current_index = self.snapshot.current_index.ok_or_else(|| {
            PlaybackError::new(
                "invalid-current-index",
                "A non-empty queue must select a current item.",
            )
        })?;
        if play_next {
            self.snapshot
                .queue
                .splice(current_index + 1..current_index + 1, additions);
        } else {
            self.snapshot.queue.extend(additions);
        }
        self.rebuild_order();
        self.bump_sequence();
        Ok(())
    }

    fn require_queue(&self) -> Result<(), PlaybackError> {
        if self.snapshot.queue.is_empty() {
            return Err(PlaybackError::new(
                "empty-queue",
                "Cannot control playback while the queue is empty.",
            ));
        }
        Ok(())
    }

    fn require_index(&self, index: usize) -> Result<(), PlaybackError> {
        if index >= self.snapshot.queue.len() {
            return Err(PlaybackError::new(
                "invalid-current-index",
                "The selected item is outside the playback queue.",
            ));
        }
        Ok(())
    }

    fn bump_sequence(&mut self) {
        self.snapshot.sequence = self.snapshot.sequence.saturating_add(1);
    }
}

fn queue_path_key(path: &str) -> String {
    path.replace('/', "\\").to_lowercase()
}

fn validate_queue_items(items: &[super::contracts::PlaybackItem]) -> Result<(), PlaybackError> {
    if items.iter().any(|item| {
        item.id.trim().is_empty() || item.path.trim().is_empty() || item.title.trim().is_empty()
    }) {
        return Err(PlaybackError::new(
            "invalid-contract",
            "Playback items must provide a non-empty id, path and title.",
        ));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::playback::contracts::{MediaKind, PlaybackItem};

    fn track(id: &str, duration_ms: Option<u64>) -> PlaybackItem {
        PlaybackItem {
            id: id.to_owned(),
            path: format!(r"C:\Music\{id}.flac"),
            title: id.to_owned(),
            kind: MediaKind::Audio,
            duration_ms,
        }
    }

    fn loaded_session() -> PlaybackSession {
        let mut session = PlaybackSession::default();
        session
            .dispatch(PlaybackCommand::ReplaceQueue {
                queue: vec![track("one", Some(60_000)), track("two", Some(70_000))],
                current_index: Some(0),
                autoplay: true,
            })
            .expect("valid queue should load");
        session
    }

    #[test]
    fn zero_volume_restores_the_previous_audible_level_when_unmuted() {
        let mut session = loaded_session();
        session
            .dispatch(PlaybackCommand::SetVolume { volume: 37.0 })
            .expect("volume");
        let zero = session
            .dispatch(PlaybackCommand::SetVolume { volume: 0.0 })
            .expect("zero");
        assert!(zero.muted);
        assert_eq!(session.preferences().last_audible_volume, 37.0);
        let restored = session
            .dispatch(PlaybackCommand::SetMuted { muted: false })
            .expect("unmute");
        assert_eq!(restored.volume, 37.0);
        assert!(!restored.muted);
    }

    #[test]
    fn moving_to_a_positive_volume_unmutes_and_remembers_the_new_level() {
        let mut session = loaded_session();
        session
            .dispatch(PlaybackCommand::SetMuted { muted: true })
            .expect("mute");
        let updated = session
            .dispatch(PlaybackCommand::SetVolume { volume: 41.0 })
            .expect("adjust");
        assert!(!updated.muted);
        assert_eq!(session.preferences().last_audible_volume, 41.0);
    }

    #[test]
    fn invalid_restore_is_muted_without_overwriting_the_preference_error() {
        let mut session = PlaybackSession::default();
        session.restore_preferences(Err(PlaybackError::new(
            "preferences-unavailable",
            "restore failed",
        )));
        let snapshot = session.snapshot();
        assert!(snapshot.muted);
        assert_eq!(snapshot.volume, 0.0);
        assert!(snapshot.preferences_error.is_some());
        session
            .dispatch(PlaybackCommand::ReplaceQueue {
                queue: vec![track("one", Some(60_000))],
                current_index: Some(0),
                autoplay: true,
            })
            .expect("play under safe mute");
        assert!(session.snapshot().preferences_error.is_some());
        session
            .dispatch(PlaybackCommand::SetMuted { muted: false })
            .expect("explicit recovery");
        assert_eq!(session.snapshot().volume, 60.0);
        assert!(session.snapshot().preferences_error.is_none());
    }

    #[test]
    fn conditional_reads_keep_position_sampling_out_of_the_state_version() {
        let mut session = loaded_session();
        let version = PlaybackVersion {
            generation: 1,
            sequence: 0,
        };
        session.sync_runtime(3_000, Some(61_000), false, false);
        let PlaybackUpdate::Position { position } = session.update(version) else {
            panic!("unchanged state must return a narrow position sample");
        };
        assert_eq!(position.generation, 1);
        assert_eq!(position.sequence, 0);
        assert_eq!(position.media_id.as_deref(), Some("one"));
        assert_eq!(position.position_ms, 3_000);
        assert_eq!(position.duration_ms, Some(61_000));
        assert_eq!(session.snapshot().sequence, 0);
        session.dispatch(PlaybackCommand::Pause).expect("pause");
        let PlaybackUpdate::Snapshot { snapshot } = session.update(version) else {
            panic!("a state transition must return a complete snapshot");
        };
        assert_eq!(snapshot.status, PlaybackStatus::Paused);
        assert_eq!(snapshot.sequence, 1);
    }

    #[test]
    fn only_an_exact_version_can_request_a_narrow_response() {
        let session = loaded_session();
        for version in [
            PlaybackVersion {
                generation: 0,
                sequence: 99,
            },
            PlaybackVersion {
                generation: 2,
                sequence: 0,
            },
            PlaybackVersion {
                generation: 1,
                sequence: 1,
            },
        ] {
            assert!(matches!(
                session.update(version),
                PlaybackUpdate::Snapshot { .. }
            ));
        }
    }

    #[test]
    fn idle_position_reads_have_no_media_reference() {
        let session = PlaybackSession::default();
        let PlaybackUpdate::Position { position } = session.update(PlaybackVersion {
            generation: 0,
            sequence: 0,
        }) else {
            panic!("idle position sample");
        };
        assert_eq!(position.status, PlaybackStatus::Idle);
        assert_eq!(position.media_id, None);
        assert_eq!(position.position_ms, 0);
        assert_eq!(position.duration_ms, None);
    }

    #[test]
    fn position_wire_size_does_not_grow_with_a_five_thousand_item_queue() {
        let mut session = PlaybackSession::default();
        let snapshot = session
            .dispatch(PlaybackCommand::ReplaceQueue {
                queue: (0..5_000)
                    .map(|index| track(&format!("track-{index}"), Some(60_000)))
                    .collect(),
                current_index: Some(0),
                autoplay: true,
            })
            .expect("large queue");
        let position = serde_json::to_vec(&session.update(PlaybackVersion {
            generation: snapshot.generation,
            sequence: snapshot.sequence,
        }))
        .expect("position wire");
        let full =
            serde_json::to_vec(&PlaybackUpdate::Snapshot { snapshot }).expect("snapshot wire");
        assert!(position.len() < 256);
        assert!(full.len() > 500_000);
        eprintln!(
            "5000-item conditional poll: {} bytes; full update: {} bytes",
            position.len(),
            full.len()
        );
    }

    #[test]
    fn refreshing_a_relocated_item_preserves_queue_position_and_identity() {
        let mut session = loaded_session();
        session
            .dispatch(PlaybackCommand::Seek {
                position_ms: 12_000,
            })
            .expect("seek");
        let previous_generation = session.snapshot().generation;
        let mut replacement = track("one", Some(90_000));
        replacement.path = r"D:\Recovered\one.flac".to_owned();
        replacement.title = "recovered.flac".to_owned();

        let snapshot = session
            .dispatch(PlaybackCommand::RefreshItem { item: replacement })
            .expect("refresh");

        assert_eq!(snapshot.queue[0].id, "one");
        assert_eq!(snapshot.queue[0].path, r"D:\Recovered\one.flac");
        assert_eq!(snapshot.current_index, Some(0));
        assert_eq!(snapshot.position_ms, 12_000);
        assert_eq!(snapshot.duration_ms, Some(90_000));
        assert_eq!(snapshot.generation, previous_generation + 1);
    }

    #[test]
    fn rejects_play_for_an_empty_queue() {
        let mut session = PlaybackSession::default();

        let result = session.dispatch(PlaybackCommand::Play);

        assert_eq!(
            result.expect_err("empty queue should fail").code,
            "empty-queue"
        );
    }

    #[test]
    fn replacing_the_queue_starts_a_new_generation() {
        let mut session = PlaybackSession::default();

        let snapshot = session
            .dispatch(PlaybackCommand::ReplaceQueue {
                queue: vec![track("one", Some(60_000))],
                current_index: Some(0),
                autoplay: true,
            })
            .expect("valid queue should load");

        assert_eq!(snapshot.generation, 1);
        assert_eq!(snapshot.sequence, 0);
        assert_eq!(snapshot.status, PlaybackStatus::Playing);
        assert_eq!(snapshot.duration_ms, Some(60_000));
    }

    #[test]
    fn manual_next_advances_while_repeat_one_is_active() {
        let mut session = loaded_session();
        session
            .dispatch(PlaybackCommand::SetRepeatMode {
                repeat_mode: RepeatMode::One,
            })
            .expect("mode");

        let snapshot = session.dispatch(PlaybackCommand::Next).expect("next");

        assert_eq!(snapshot.current_index, Some(1));
        assert_eq!(snapshot.generation, 2);
    }

    #[test]
    fn automatic_advance_repeats_the_current_item_in_repeat_one() {
        let mut session = loaded_session();
        session
            .dispatch(PlaybackCommand::SetRepeatMode {
                repeat_mode: RepeatMode::One,
            })
            .expect("mode");
        session.sync_runtime(60_000, Some(60_000), true, false);

        assert!(session.advance_automatically().expect("automatic advance"));
        let snapshot = session.snapshot();

        assert_eq!(snapshot.current_index, Some(0));
        assert_eq!(snapshot.generation, 2);
        assert_eq!(snapshot.status, PlaybackStatus::Playing);
    }

    #[test]
    fn automatic_advance_stops_at_the_end_without_repeat() {
        let mut session = loaded_session();
        session
            .dispatch(PlaybackCommand::PlayIndex { index: 1 })
            .expect("last item");
        session
            .dispatch(PlaybackCommand::SetRepeatMode {
                repeat_mode: RepeatMode::None,
            })
            .expect("mode");
        session.sync_runtime(70_000, Some(70_000), true, false);

        assert!(!session.advance_automatically().expect("automatic advance"));
        assert_eq!(session.snapshot().status, PlaybackStatus::Completed);
        assert_eq!(session.snapshot().current_index, Some(1));
    }

    #[test]
    fn seek_is_clamped_to_the_known_duration() {
        let mut session = loaded_session();

        let snapshot = session
            .dispatch(PlaybackCommand::Seek {
                position_ms: 90_000,
            })
            .expect("loaded queue should seek");

        assert_eq!(snapshot.position_ms, 60_000);
    }

    #[test]
    fn rejects_an_out_of_range_volume_at_the_rust_boundary() {
        let mut session = PlaybackSession::default();

        let result = session.dispatch(PlaybackCommand::SetVolume { volume: 101.0 });

        assert_eq!(
            result.expect_err("invalid volume should fail").code,
            "invalid-contract"
        );
    }

    #[test]
    fn rejects_a_non_empty_queue_without_a_current_item() {
        let mut session = PlaybackSession::default();

        let result = session.dispatch(PlaybackCommand::ReplaceQueue {
            queue: vec![track("one", None)],
            current_index: None,
            autoplay: false,
        });

        assert_eq!(
            result.expect_err("missing current item should fail").code,
            "invalid-current-index"
        );
    }

    #[test]
    fn rejects_duplicate_paths_case_insensitively() {
        let mut session = PlaybackSession::default();
        let mut duplicate = track("two", None);
        duplicate.path = r"c:/music/ONE.flac".to_owned();

        let result = session.dispatch(PlaybackCommand::ReplaceQueue {
            queue: vec![track("one", None), duplicate],
            current_index: Some(0),
            autoplay: false,
        });

        assert_eq!(
            result.expect_err("duplicate path should fail").code,
            "duplicate-queue-item"
        );
    }

    #[test]
    fn playing_again_after_completion_rewinds_the_session() {
        let mut session = loaded_session();
        session.sync_runtime(60_000, Some(60_000), true, false);

        let snapshot = session.dispatch(PlaybackCommand::Play).expect("replay");

        assert_eq!(snapshot.status, PlaybackStatus::Playing);
        assert_eq!(snapshot.position_ms, 0);
    }

    #[test]
    fn previous_at_the_start_replays_the_current_item_without_repeat() {
        let mut session = loaded_session();
        session
            .dispatch(PlaybackCommand::SetRepeatMode {
                repeat_mode: RepeatMode::None,
            })
            .expect("mode");

        let snapshot = session
            .dispatch(PlaybackCommand::Previous)
            .expect("previous");

        assert_eq!(snapshot.current_index, Some(0));
        assert_eq!(snapshot.generation, 2);
    }

    #[test]
    fn removing_the_current_item_loads_the_nearest_remaining_item() {
        let mut session = loaded_session();

        let snapshot = session
            .dispatch(PlaybackCommand::RemoveIndex { index: 0 })
            .expect("remove current");

        assert_eq!(snapshot.queue.len(), 1);
        assert_eq!(snapshot.current_index, Some(0));
        assert_eq!(snapshot.queue[0].id, "two");
        assert_eq!(snapshot.generation, 2);
        assert_eq!(snapshot.status, PlaybackStatus::Playing);
    }

    #[test]
    fn removing_an_item_before_current_preserves_the_active_media_generation() {
        let mut session = loaded_session();
        session
            .dispatch(PlaybackCommand::PlayIndex { index: 1 })
            .expect("play second");
        let generation = session.snapshot().generation;

        let snapshot = session
            .dispatch(PlaybackCommand::RemoveIndex { index: 0 })
            .expect("remove earlier item");

        assert_eq!(snapshot.current_index, Some(0));
        assert_eq!(snapshot.queue[0].id, "two");
        assert_eq!(snapshot.generation, generation);
    }

    #[test]
    fn removing_the_only_item_returns_to_an_idle_queue() {
        let mut session = PlaybackSession::default();
        session
            .dispatch(PlaybackCommand::ReplaceQueue {
                queue: vec![track("one", None)],
                current_index: Some(0),
                autoplay: true,
            })
            .expect("load");

        let snapshot = session
            .dispatch(PlaybackCommand::RemoveIndex { index: 0 })
            .expect("remove only item");

        assert!(snapshot.queue.is_empty());
        assert_eq!(snapshot.current_index, None);
        assert_eq!(snapshot.status, PlaybackStatus::Idle);
    }

    #[test]
    fn reordering_preserves_the_active_media_generation_and_runtime_state() {
        let mut session = PlaybackSession::default();
        session
            .dispatch(PlaybackCommand::ReplaceQueue {
                queue: vec![
                    track("one", Some(60_000)),
                    track("two", Some(70_000)),
                    track("three", Some(80_000)),
                ],
                current_index: Some(1),
                autoplay: true,
            })
            .expect("load");
        session
            .dispatch(PlaybackCommand::Seek {
                position_ms: 12_000,
            })
            .expect("seek");
        let before = session.snapshot();

        let snapshot = session
            .dispatch(PlaybackCommand::ReorderQueue {
                from_index: 0,
                to_index: 2,
            })
            .expect("reorder around current");

        assert_eq!(
            snapshot
                .queue
                .iter()
                .map(|item| &item.id)
                .collect::<Vec<_>>(),
            ["two", "three", "one"]
        );
        assert_eq!(snapshot.current_index, Some(0));
        assert_eq!(snapshot.queue[snapshot.current_index.unwrap()].id, "two");
        assert_eq!(snapshot.generation, before.generation);
        assert_eq!(snapshot.sequence, before.sequence + 1);
        assert_eq!(snapshot.position_ms, before.position_ms);
        assert_eq!(snapshot.status, before.status);
    }

    #[test]
    fn reordering_the_current_item_moves_its_index_without_reloading_it() {
        let mut session = PlaybackSession::default();
        session
            .dispatch(PlaybackCommand::ReplaceQueue {
                queue: vec![track("one", None), track("two", None), track("three", None)],
                current_index: Some(1),
                autoplay: true,
            })
            .expect("load");
        let generation = session.snapshot().generation;

        let snapshot = session
            .dispatch(PlaybackCommand::ReorderQueue {
                from_index: 1,
                to_index: 2,
            })
            .expect("move current");

        assert_eq!(snapshot.current_index, Some(2));
        assert_eq!(snapshot.queue[2].id, "two");
        assert_eq!(snapshot.generation, generation);
    }

    #[test]
    fn invalid_reorder_indexes_leave_the_session_unchanged() {
        let mut session = loaded_session();
        let before = session.snapshot();

        let error = session
            .dispatch(PlaybackCommand::ReorderQueue {
                from_index: 0,
                to_index: 2,
            })
            .expect_err("out of range target should fail");

        assert_eq!(error.code, "invalid-current-index");
        assert_eq!(
            session
                .snapshot()
                .queue
                .iter()
                .map(|item| &item.id)
                .collect::<Vec<_>>(),
            before.queue.iter().map(|item| &item.id).collect::<Vec<_>>()
        );
        assert_eq!(session.snapshot().current_index, before.current_index);
        assert_eq!(session.snapshot().sequence, before.sequence);
    }

    #[test]
    fn enqueue_appends_unique_items_without_reloading_the_current_media() {
        let mut session = loaded_session();
        let generation = session.snapshot().generation;

        let snapshot = session
            .dispatch(PlaybackCommand::Enqueue {
                items: vec![track("two", None), track("three", None)],
            })
            .expect("enqueue");

        assert_eq!(
            snapshot
                .queue
                .iter()
                .map(|item| &item.id)
                .collect::<Vec<_>>(),
            ["one", "two", "three"]
        );
        assert_eq!(snapshot.current_index, Some(0));
        assert_eq!(snapshot.generation, generation);
    }

    #[test]
    fn play_next_inserts_unique_items_after_the_current_item() {
        let mut session = loaded_session();

        let snapshot = session
            .dispatch(PlaybackCommand::PlayNext {
                items: vec![track("three", None)],
            })
            .expect("play next");

        assert_eq!(
            snapshot
                .queue
                .iter()
                .map(|item| &item.id)
                .collect::<Vec<_>>(),
            ["one", "three", "two"]
        );
        assert_eq!(snapshot.current_index, Some(0));
    }

    #[test]
    fn enqueue_into_an_empty_queue_starts_the_first_unique_item() {
        let mut session = PlaybackSession::default();

        let snapshot = session
            .dispatch(PlaybackCommand::Enqueue {
                items: vec![track("one", None), track("one", None)],
            })
            .expect("enqueue empty");

        assert_eq!(snapshot.queue.len(), 1);
        assert_eq!(snapshot.current_index, Some(0));
        assert_eq!(snapshot.status, PlaybackStatus::Playing);
        assert_eq!(snapshot.generation, 1);
    }
}
