use serde::{Deserialize, Serialize};

use super::contracts::PlaybackError;

#[derive(Clone, Copy, Debug, Deserialize, PartialEq, Serialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct PlaybackPreferences {
    pub volume: f64,
    pub muted: bool,
    pub last_audible_volume: f64,
}

impl Default for PlaybackPreferences {
    fn default() -> Self {
        Self {
            volume: 100.0,
            muted: false,
            last_audible_volume: 100.0,
        }
    }
}

impl PlaybackPreferences {
    pub(crate) fn validate(self) -> Result<Self, PlaybackError> {
        if !self.volume.is_finite()
            || !(0.0..=100.0).contains(&self.volume)
            || !self.last_audible_volume.is_finite()
            || !(1.0..=100.0).contains(&self.last_audible_volume)
            || (self.volume == 0.0 && !self.muted)
        {
            return Err(PlaybackError::new(
                "preferences-unavailable",
                "The saved audio preferences are invalid.",
            ));
        }
        Ok(self)
    }

    pub(super) fn muted_fallback() -> Self {
        Self {
            volume: 0.0,
            muted: true,
            last_audible_volume: 60.0,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn validates_the_saved_range_and_zero_volume_mute_invariant() {
        assert!(PlaybackPreferences::default().validate().is_ok());
        assert!(PlaybackPreferences::muted_fallback().validate().is_ok());
        for preferences in [
            PlaybackPreferences {
                volume: f64::NAN,
                ..PlaybackPreferences::default()
            },
            PlaybackPreferences {
                volume: f64::INFINITY,
                ..PlaybackPreferences::default()
            },
            PlaybackPreferences {
                volume: -1.0,
                ..PlaybackPreferences::default()
            },
            PlaybackPreferences {
                volume: 101.0,
                ..PlaybackPreferences::default()
            },
            PlaybackPreferences {
                volume: 0.0,
                muted: false,
                ..PlaybackPreferences::default()
            },
            PlaybackPreferences {
                last_audible_volume: 0.0,
                ..PlaybackPreferences::default()
            },
            PlaybackPreferences {
                last_audible_volume: f64::NAN,
                ..PlaybackPreferences::default()
            },
        ] {
            assert!(preferences.validate().is_err());
        }
    }

    #[test]
    fn rejects_unknown_or_missing_saved_fields() {
        for json in [
            r#"{"volume":30,"muted":false}"#,
            r#"{"volume":30,"muted":false,"lastAudibleVolume":30,"unexpected":true}"#,
        ] {
            assert!(serde_json::from_str::<PlaybackPreferences>(json).is_err());
        }
    }
}
