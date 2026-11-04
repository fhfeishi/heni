use super::contracts::RepeatMode;

/// A shuffle round is a permutation of the whole queue. The current item is the
/// round's starting point; `upcoming` holds the rest of this round. When it is
/// exhausted a fresh round is generated, so consecutive rounds never replay the
/// same fixed sequence and never put the same track back-to-back at the seam.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(super) struct PlaybackOrder {
    length: usize,
    shuffle: bool,
    current: Option<usize>,
    upcoming: Vec<usize>,
    /// Played items, newest last. Kept across rounds so Previous can walk back.
    history: Vec<usize>,
    /// The current round's full order, used to reject an identical next round.
    round: Vec<usize>,
}

pub(super) enum OrderMove {
    Stop,
    Play { order: PlaybackOrder, index: usize },
}

impl PlaybackOrder {
    pub(super) fn build(length: usize, current_index: usize, shuffle: bool) -> Self {
        if length == 0 {
            return Self {
                length: 0,
                shuffle,
                current: None,
                upcoming: Vec::new(),
                history: Vec::new(),
                round: Vec::new(),
            };
        }

        let current = current_index.min(length - 1);
        let mut order = Self {
            length,
            shuffle,
            current: Some(current),
            upcoming: Vec::new(),
            history: Vec::new(),
            round: Vec::new(),
        };
        order.upcoming = order.first_round(current);
        order.round = order.current_round();
        order.ensure_upcoming();
        order
    }

    /// Rebuild after a queue edit without throwing away what was already heard.
    /// Recently played items are pushed to the back of the new round.
    pub(super) fn rebuild(&self, length: usize, current_index: usize, shuffle: bool) -> Self {
        if length == 0 {
            return Self::build(0, 0, shuffle);
        }
        let current = current_index.min(length - 1);
        let limit = length.saturating_mul(2).max(1);
        let mut history = self
            .history
            .iter()
            .copied()
            .filter(|index| *index < length && *index != current)
            .collect::<Vec<_>>();
        if history.len() > limit {
            history.drain(..history.len() - limit);
        }

        let mut order = Self {
            length,
            shuffle,
            current: Some(current),
            upcoming: Vec::new(),
            history,
            round: Vec::new(),
        };
        let mut upcoming = order.first_round(current);
        for played in order
            .history
            .iter()
            .rev()
            .take(upcoming.len().saturating_sub(1))
        {
            if let Some(at) = upcoming.iter().position(|index| index == played) {
                let item = upcoming.remove(at);
                upcoming.push(item);
            }
        }
        order.upcoming = upcoming;
        order.round = order.current_round();
        order.ensure_upcoming();
        order
    }

    pub(super) fn next(&self, repeat_mode: RepeatMode) -> OrderMove {
        let Some(current) = self.current else {
            return OrderMove::Stop;
        };
        if repeat_mode == RepeatMode::One {
            return OrderMove::Play {
                order: self.clone(),
                index: current,
            };
        }

        let mut order = self.clone();
        let index = order.upcoming.remove(0);
        order.push_history(current);
        order.current = Some(index);
        // Prepare the next round while the last item of this one is playing, so
        // peek_next and next always read the same generated sequence.
        if order.upcoming.is_empty() {
            let round = order.fresh_round(Some(index));
            order.round = round.clone();
            order.upcoming = round;
        }
        OrderMove::Play { order, index }
    }

    pub(super) fn previous(&self, _repeat_mode: RepeatMode) -> OrderMove {
        let Some(current) = self.current else {
            return OrderMove::Stop;
        };
        let mut order = self.clone();
        let previous = if let Some(index) = order.history.pop() {
            index
        } else if order.length > 1 {
            if order.shuffle {
                let mut round = (0..order.length).collect::<Vec<_>>();
                fastrand::shuffle(&mut round);
                round
                    .iter()
                    .rev()
                    .find(|index| **index != current)
                    .copied()
                    .unwrap_or(current)
            } else {
                (current + order.length - 1) % order.length
            }
        } else {
            current
        };
        // Going forward again must replay the item we just stepped back from.
        order.upcoming.insert(0, current);
        order.current = Some(previous);
        OrderMove::Play {
            order,
            index: previous,
        }
    }

    /// The track that `next` would choose, without consuming the round.
    pub(super) fn peek_next(&self, repeat_mode: RepeatMode) -> Option<usize> {
        let current = self.current?;
        if repeat_mode == RepeatMode::One {
            return Some(current);
        }
        self.upcoming.first().copied()
    }

    fn ensure_upcoming(&mut self) {
        if self.upcoming.is_empty() && self.length > 0 {
            let round = self.fresh_round(self.current);
            self.round = round.clone();
            self.upcoming = round;
        }
    }

    fn first_round(&self, current: usize) -> Vec<usize> {
        if self.shuffle {
            let mut rest = (0..self.length)
                .filter(|index| *index != current)
                .collect::<Vec<_>>();
            fastrand::shuffle(&mut rest);
            rest
        } else {
            (current + 1..self.length).chain(0..current).collect()
        }
    }

    fn current_round(&self) -> Vec<usize> {
        self.current
            .into_iter()
            .chain(self.upcoming.iter().copied())
            .collect()
    }

    fn fresh_round(&self, avoid_first: Option<usize>) -> Vec<usize> {
        let mut round = (0..self.length).collect::<Vec<_>>();
        if !self.shuffle || self.length < 2 {
            return round;
        }

        fastrand::shuffle(&mut round);
        let acceptable = |candidate: &[usize]| {
            avoid_first.is_none_or(|avoid| candidate.first() != Some(&avoid))
                && candidate != self.round.as_slice()
        };
        if !acceptable(&round) {
            // Resolve both constraints (no track repeated at the seam, no repeated
            // round order) with a single swap rather than another full shuffle.
            for swap_with in 1..round.len() {
                round.swap(0, swap_with);
                if acceptable(&round) {
                    break;
                }
            }
        }
        round
    }

    fn push_history(&mut self, index: usize) {
        let limit = self.length.saturating_mul(2).max(1);
        self.history.push(index);
        if self.history.len() > limit {
            self.history.remove(0);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn played_index(movement: OrderMove) -> Option<usize> {
        match movement {
            OrderMove::Stop => None,
            OrderMove::Play { index, .. } => Some(index),
        }
    }

    fn next_order(order: &PlaybackOrder, mode: RepeatMode) -> PlaybackOrder {
        let OrderMove::Play { order, .. } = order.next(mode) else {
            panic!("a loaded order must always advance");
        };
        order
    }

    #[test]
    fn linear_order_wraps_at_the_end() {
        assert_eq!(
            played_index(PlaybackOrder::build(3, 2, false).next(RepeatMode::None)),
            Some(0)
        );
        assert_eq!(
            played_index(PlaybackOrder::build(3, 0, false).previous(RepeatMode::All)),
            Some(2)
        );
    }

    #[test]
    fn repeat_all_wraps_in_both_directions() {
        let last = PlaybackOrder::build(3, 2, false);
        let first = PlaybackOrder::build(3, 0, false);

        assert_eq!(played_index(last.next(RepeatMode::All)), Some(0));
        assert_eq!(played_index(first.previous(RepeatMode::All)), Some(2));
    }

    #[test]
    fn repeat_one_keeps_the_current_item() {
        let order = PlaybackOrder::build(4, 2, false);

        assert_eq!(played_index(order.next(RepeatMode::One)), Some(2));
        assert_eq!(order.peek_next(RepeatMode::One), Some(2));
    }

    #[test]
    fn shuffled_order_starts_on_the_current_item_and_visits_every_track_once() {
        let order = PlaybackOrder::build(5, 3, true);

        assert_eq!(order.current, Some(3));
        assert_eq!(order.round[0], 3);
        let mut visited = order.current_round();
        visited.sort_unstable();
        assert_eq!(visited, [0, 1, 2, 3, 4]);

        let mut played = vec![3];
        let mut cursor = order;
        for _ in 0..4 {
            let next = next_order(&cursor, RepeatMode::All);
            played.push(next.current.expect("current item"));
            cursor = next;
        }
        played.sort_unstable();
        assert_eq!(played, [0, 1, 2, 3, 4]);
    }

    #[test]
    fn every_shuffle_round_is_a_permutation_and_never_repeats_the_seam() {
        let mut cursor = PlaybackOrder::build(8, 0, true);
        let mut previous = 0;
        let mut visited = vec![0];
        for _ in 0..7 {
            cursor = next_order(&cursor, RepeatMode::All);
            let current = cursor.current.expect("current item");
            assert_ne!(current, previous);
            previous = current;
            visited.push(current);
        }
        visited.sort_unstable();
        assert_eq!(visited, [0, 1, 2, 3, 4, 5, 6, 7]);

        for round in 0..20 {
            assert_ne!(
                cursor.peek_next(RepeatMode::All),
                Some(previous),
                "round {round} repeated the last track at the seam"
            );
            let mut visited = Vec::new();
            for _ in 0..8 {
                cursor = next_order(&cursor, RepeatMode::All);
                let current = cursor.current.expect("current item");
                assert_ne!(current, previous, "round {round} repeated a track");
                previous = current;
                visited.push(current);
            }
            visited.sort_unstable();
            assert_eq!(visited, [0, 1, 2, 3, 4, 5, 6, 7]);
        }
    }

    #[test]
    fn consecutive_shuffle_rounds_are_not_identical() {
        let mut cursor = PlaybackOrder::build(6, 0, true);
        let first_round = cursor.round.clone();
        for _ in 0..5 {
            cursor = next_order(&cursor, RepeatMode::All);
        }
        // The round prepared while the last track plays must differ from the last one.
        assert_ne!(cursor.round, first_round);
        assert_eq!(cursor.upcoming, cursor.round);
    }

    #[test]
    fn peek_next_matches_the_track_that_next_actually_plays_across_rounds() {
        let mut cursor = PlaybackOrder::build(7, 0, true);
        for _ in 0..40 {
            let predicted = cursor.peek_next(RepeatMode::All);
            let OrderMove::Play { order, index } = cursor.next(RepeatMode::All) else {
                panic!("a loaded order must always advance");
            };
            assert_eq!(predicted, Some(index));
            cursor = order;
        }
    }

    #[test]
    fn previous_walks_back_across_rounds_and_forward_replays_in_order() {
        let mut cursor = PlaybackOrder::build(4, 0, false);
        let mut played = vec![0];
        for _ in 0..5 {
            cursor = next_order(&cursor, RepeatMode::All);
            played.push(cursor.current.expect("current item"));
        }
        let mut walked_back = Vec::new();
        for _ in 0..3 {
            let OrderMove::Play { order, index } = cursor.previous(RepeatMode::All) else {
                panic!("previous must walk the history");
            };
            cursor = order;
            walked_back.push(index);
        }
        let expected = played[..played.len() - 1]
            .iter()
            .rev()
            .take(3)
            .copied()
            .collect::<Vec<_>>();
        assert_eq!(walked_back, expected);
    }

    #[test]
    fn rebuilding_keeps_history_and_defers_recently_played_tracks() {
        let mut cursor = PlaybackOrder::build(5, 0, true);
        cursor = next_order(&cursor, RepeatMode::All);
        cursor = next_order(&cursor, RepeatMode::All);
        let heard = cursor.history.clone();

        let rebuilt = cursor.rebuild(6, 5, true);
        assert!(heard.iter().all(|index| rebuilt.history.contains(index)));
        assert_eq!(rebuilt.current, Some(5));
        let mut round = rebuilt.current_round();
        round.sort_unstable();
        assert_eq!(round, [0, 1, 2, 3, 4, 5]);
    }

    #[test]
    fn empty_order_never_advances() {
        let order = PlaybackOrder::build(0, 0, true);
        assert_eq!(played_index(order.next(RepeatMode::All)), None);
        assert_eq!(played_index(order.previous(RepeatMode::All)), None);
        assert_eq!(order.peek_next(RepeatMode::All), None);
    }
}
