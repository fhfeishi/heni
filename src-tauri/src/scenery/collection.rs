use serde::{Deserialize, Serialize};

pub(crate) const MAX_IMAGES: usize = 12;

/// Persist references only; decoded images are never stored in SQLite.
#[derive(Clone, Debug, Default, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct SceneryCollection {
    pub(crate) paths: Vec<String>,
    pub(crate) index: usize,
}

impl SceneryCollection {
    pub(crate) fn valid(&self) -> bool {
        self.paths.len() <= MAX_IMAGES
            && self.paths.iter().all(|path| !path.is_empty())
            && if self.paths.is_empty() {
                self.index == 0
            } else {
                self.index < self.paths.len()
            }
    }

    pub(crate) fn current(&self) -> Option<&str> {
        self.paths.get(self.index).map(String::as_str)
    }

    pub(crate) fn advance(&mut self, forward: bool) {
        if self.paths.is_empty() {
            return;
        }
        self.index = if forward {
            (self.index + 1) % self.paths.len()
        } else {
            (self.index + self.paths.len() - 1) % self.paths.len()
        };
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn wraps_both_directions_and_handles_empty_and_single_collections() {
        let mut value = SceneryCollection::default();
        value.advance(false);
        assert_eq!(value.index, 0);
        value.paths = vec!["one".into(), "two".into()];
        value.advance(false);
        assert_eq!(value.current(), Some("two"));
        value.advance(true);
        assert_eq!(value.current(), Some("one"));
        value.paths.pop();
        value.advance(true);
        assert_eq!(value.index, 0);
    }

    #[test]
    fn rejects_invalid_indices_and_unbounded_collections() {
        assert!(!SceneryCollection {
            paths: vec!["one".into()],
            index: 1
        }
        .valid());
        assert!(!SceneryCollection {
            paths: vec!["one".into(); MAX_IMAGES + 1],
            index: 0
        }
        .valid());
        assert!(!SceneryCollection {
            paths: vec![String::new()],
            index: 0
        }
        .valid());
    }
}
