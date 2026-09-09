use super::contracts::RepeatMode;

#[derive(Clone, Debug, PartialEq, Eq)]
pub(super) struct PlaybackOrder {
    indices: Vec<usize>,
    position: Option<usize>,
}

pub(super) enum OrderMove {
    Stop,
    Play { order: PlaybackOrder, index: usize },
}

impl PlaybackOrder {
    pub(super) fn build(length: usize, current_index: usize, shuffle: bool) -> Self {
        if length == 0 {
            return Self {
                indices: Vec::new(),
                position: None,
            };
        }

        let current_index = current_index.min(length - 1);
        if !shuffle {
            return Self {
                indices: (0..length).collect(),
                position: Some(current_index),
            };
        }

        let mut rest = (0..length)
            .filter(|index| *index != current_index)
            .collect::<Vec<_>>();
        fastrand::shuffle(&mut rest);
        let mut indices = Vec::with_capacity(length);
        indices.push(current_index);
        indices.extend(rest);
        Self {
            indices,
            position: Some(0),
        }
    }

    pub(super) fn next(&self, repeat_mode: RepeatMode) -> OrderMove {
        let Some(position) = self.position else {
            return OrderMove::Stop;
        };
        let Some(&current_index) = self.indices.get(position) else {
            return OrderMove::Stop;
        };

        if repeat_mode == RepeatMode::One {
            return OrderMove::Play {
                order: self.clone(),
                index: current_index,
            };
        }

        let next_position = position + 1;
        if let Some(&index) = self.indices.get(next_position) {
            return OrderMove::Play {
                order: Self {
                    indices: self.indices.clone(),
                    position: Some(next_position),
                },
                index,
            };
        }

        if repeat_mode == RepeatMode::All {
            return OrderMove::Play {
                order: Self {
                    indices: self.indices.clone(),
                    position: Some(0),
                },
                index: self.indices[0],
            };
        }
        OrderMove::Stop
    }

    pub(super) fn previous(&self, repeat_mode: RepeatMode) -> OrderMove {
        let Some(position) = self.position else {
            return OrderMove::Stop;
        };
        let Some(&current_index) = self.indices.get(position) else {
            return OrderMove::Stop;
        };

        if position > 0 {
            let previous_position = position - 1;
            return OrderMove::Play {
                order: Self {
                    indices: self.indices.clone(),
                    position: Some(previous_position),
                },
                index: self.indices[previous_position],
            };
        }

        if repeat_mode == RepeatMode::All {
            let last_position = self.indices.len() - 1;
            return OrderMove::Play {
                order: Self {
                    indices: self.indices.clone(),
                    position: Some(last_position),
                },
                index: self.indices[last_position],
            };
        }

        OrderMove::Play {
            order: self.clone(),
            index: current_index,
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

    #[test]
    fn linear_order_stops_at_the_end_without_repeat() {
        let order = PlaybackOrder::build(3, 2, false);

        assert_eq!(played_index(order.next(RepeatMode::None)), None);
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
    }

    #[test]
    fn shuffled_order_keeps_the_current_item_first() {
        let order = PlaybackOrder::build(5, 3, true);

        assert_eq!(order.indices[0], 3);
        let mut indices = order.indices.clone();
        indices.sort_unstable();
        assert_eq!(indices, [0, 1, 2, 3, 4]);
    }
}
