use std::path::Path;

use rusqlite::{params, Connection, OptionalExtension, TransactionBehavior};

use super::contracts::{
    LibraryError, LibraryFastMetadata, LibraryImportItem, LibraryIndexedItem, LibraryItem,
    LibraryMediaKind, LibraryMetadataStatus, LibrarySnapshot,
};
use super::legacy_import::{LegacyImportPlan, LEGACY_IMPORT_KIND};
use crate::storage::migrations;

pub(crate) struct LibraryRepository {
    pub(super) connection: Connection,
}

pub(crate) struct MediaProbeTarget {
    pub(crate) media_id: String,
    pub(crate) path: String,
}

pub(crate) struct MediaRelocationTarget {
    pub(crate) kind: LibraryMediaKind,
}

impl LibraryRepository {
    pub(crate) fn open(path: &Path) -> Result<Self, LibraryError> {
        let connection = Connection::open(path).map_err(|_| LibraryError::database())?;
        Self::from_connection(connection)
    }

    pub(super) fn from_connection(mut connection: Connection) -> Result<Self, LibraryError> {
        migrations::apply(&mut connection).map_err(|_| LibraryError::database())?;
        Ok(Self { connection })
    }

    pub(crate) fn snapshot(&self) -> Result<LibrarySnapshot, LibraryError> {
        let mut statement = self
            .connection
            .prepare(
                "SELECT id, path, title, kind, duration_ms, is_available,
                        metadata_status, codec_name, sample_rate_hz, channel_count,
                        bits_per_sample, file_size_bytes, estimated_bit_rate_bps
                 FROM media
                 ORDER BY title COLLATE NOCASE, normalized_path",
            )
            .map_err(|_| LibraryError::database())?;
        let rows = statement
            .query_map([], |row| {
                let kind = match row.get::<_, String>(3)?.as_str() {
                    "audio" => LibraryMediaKind::Audio,
                    "video" => LibraryMediaKind::Video,
                    value => {
                        return Err(rusqlite::Error::InvalidColumnType(
                            3,
                            value.to_owned(),
                            rusqlite::types::Type::Text,
                        ))
                    }
                };
                let duration_ms = row
                    .get::<_, Option<i64>>(4)?
                    .map(u64::try_from)
                    .transpose()
                    .map_err(|error| {
                        rusqlite::Error::FromSqlConversionFailure(
                            4,
                            rusqlite::types::Type::Integer,
                            Box::new(error),
                        )
                    })?;
                let metadata_status = match row.get::<_, String>(6)?.as_str() {
                    "pending" => LibraryMetadataStatus::Pending,
                    "indexed" => LibraryMetadataStatus::Indexed,
                    "failed" => LibraryMetadataStatus::Failed,
                    value => {
                        return Err(rusqlite::Error::InvalidColumnType(
                            6,
                            value.to_owned(),
                            rusqlite::types::Type::Text,
                        ))
                    }
                };
                let fast_metadata = LibraryFastMetadata {
                    codec_name: row.get(7)?,
                    sample_rate_hz: optional_u32(row, 8)?,
                    channels: optional_u32(row, 9)?,
                    bits_per_sample: optional_u32(row, 10)?,
                    file_size_bytes: optional_u64(row, 11)?,
                    estimated_bit_rate_bps: optional_u64(row, 12)?,
                };
                let has_fast_metadata = fast_metadata != LibraryFastMetadata::default();
                Ok(LibraryItem {
                    id: row.get(0)?,
                    path: row.get(1)?,
                    title: row.get(2)?,
                    kind,
                    duration_ms,
                    available: row.get::<_, i64>(5)? == 1,
                    metadata_status,
                    fast_metadata: has_fast_metadata.then_some(fast_metadata),
                })
            })
            .map_err(|_| LibraryError::database())?;
        let items = rows
            .collect::<Result<Vec<_>, _>>()
            .map_err(|_| LibraryError::database())?;

        Ok(LibrarySnapshot {
            schema_version: 1,
            items,
            playlists: self.playlist_snapshot()?,
        })
    }

    #[cfg(test)]
    pub(crate) fn import_files(
        &mut self,
        items: &[LibraryImportItem],
    ) -> Result<LibrarySnapshot, LibraryError> {
        let indexed = items
            .iter()
            .cloned()
            .map(LibraryIndexedItem::pending)
            .collect::<Vec<_>>();
        self.persist_items(&indexed, ImportSource::Manual)?;
        self.snapshot()
    }

    pub(crate) fn import_indexed_files(
        &mut self,
        items: &[LibraryIndexedItem],
    ) -> Result<LibrarySnapshot, LibraryError> {
        self.persist_items(items, ImportSource::Manual)?;
        self.snapshot()
    }

    pub(crate) fn import_scanned_files(
        &mut self,
        root_id: i64,
        scan_id: &str,
        items: &[LibraryIndexedItem],
    ) -> Result<(), LibraryError> {
        self.persist_items(items, ImportSource::Root { root_id, scan_id })
    }

    pub(crate) fn register_root(
        &mut self,
        path: &str,
        recursive: bool,
        include_video: bool,
    ) -> Result<i64, LibraryError> {
        if path.trim().is_empty() {
            return Err(LibraryError::new(
                "invalid-contract",
                "A library root must provide a non-empty path.",
            ));
        }
        let normalized_path = normalized_path_key(path);
        self.connection
            .execute(
                "INSERT INTO library_roots (path, normalized_path, recursive, include_video)
                 VALUES (?1, ?2, ?3, ?4)
                 ON CONFLICT(normalized_path) DO UPDATE SET
                     recursive = excluded.recursive,
                     include_video = excluded.include_video",
                params![path, normalized_path, recursive, include_video],
            )
            .map_err(|_| LibraryError::database())?;
        self.connection
            .query_row(
                "SELECT id FROM library_roots WHERE normalized_path = ?1",
                [normalized_path],
                |row| row.get(0),
            )
            .map_err(|_| LibraryError::database())
    }

    fn persist_items(
        &mut self,
        items: &[LibraryIndexedItem],
        source: ImportSource<'_>,
    ) -> Result<(), LibraryError> {
        let prepared = items
            .iter()
            .map(validate_indexed_item)
            .collect::<Result<Vec<_>, _>>()?;
        let transaction = self
            .connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(|_| LibraryError::database())?;

        for item in prepared {
            transaction
                .execute(
                    "INSERT INTO media (
                         id, path, normalized_path, title, kind, duration_ms, is_available,
                         metadata_status, codec_name, sample_rate_hz, channel_count,
                         bits_per_sample, file_size_bytes, estimated_bit_rate_bps
                     ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, 1, ?7, ?8, ?9, ?10, ?11, ?12, ?13)
                     ON CONFLICT(normalized_path) DO UPDATE SET
                         title = excluded.title,
                         kind = excluded.kind,
                         duration_ms = COALESCE(excluded.duration_ms, media.duration_ms),
                         metadata_status = CASE
                             WHEN excluded.metadata_status = 'indexed' THEN 'indexed'
                             WHEN media.metadata_status = 'indexed' THEN media.metadata_status
                             ELSE excluded.metadata_status END,
                         codec_name = COALESCE(excluded.codec_name, media.codec_name),
                         sample_rate_hz = COALESCE(excluded.sample_rate_hz, media.sample_rate_hz),
                         channel_count = COALESCE(excluded.channel_count, media.channel_count),
                         bits_per_sample = COALESCE(excluded.bits_per_sample, media.bits_per_sample),
                         file_size_bytes = COALESCE(excluded.file_size_bytes, media.file_size_bytes),
                         estimated_bit_rate_bps = COALESCE(
                             excluded.estimated_bit_rate_bps,
                             media.estimated_bit_rate_bps
                         ),
                         is_available = 1,
                         updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')",
                    params![
                        item.normalized_path,
                        item.path,
                        item.normalized_path,
                        item.title,
                        item.kind.as_str(),
                        item.duration_ms,
                        item.metadata_status.as_str(),
                        item.codec_name,
                        item.sample_rate_hz,
                        item.channels,
                        item.bits_per_sample,
                        item.file_size_bytes,
                        item.estimated_bit_rate_bps,
                    ],
                )
                .map_err(|_| LibraryError::database())?;
            let media_id = transaction
                .query_row(
                    "SELECT id FROM media WHERE normalized_path = ?1",
                    [&item.normalized_path],
                    |row| row.get::<_, String>(0),
                )
                .map_err(|_| LibraryError::database())?;
            match source {
                ImportSource::Manual => {
                    transaction
                        .execute(
                            "INSERT INTO manual_imports (media_id)
                             VALUES (?1)
                             ON CONFLICT(media_id) DO UPDATE SET
                                 selected_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')",
                            [media_id],
                        )
                        .map_err(|_| LibraryError::database())?;
                }
                ImportSource::Root { root_id, scan_id } => {
                    transaction
                        .execute(
                            "INSERT INTO root_media (root_id, media_id, last_seen_scan)
                             VALUES (?1, ?2, ?3)
                             ON CONFLICT(root_id, media_id) DO UPDATE SET
                                 last_seen_scan = excluded.last_seen_scan",
                            params![root_id, media_id, scan_id],
                        )
                        .map_err(|_| LibraryError::database())?;
                }
            }
        }

        transaction.commit().map_err(|_| LibraryError::database())
    }

    pub(crate) fn complete_root_scan(
        &mut self,
        root_id: i64,
        scan_id: &str,
    ) -> Result<(), LibraryError> {
        let transaction = self
            .connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(|_| LibraryError::database())?;
        transaction
            .execute(
                "DELETE FROM root_media
                 WHERE root_id = ?1 AND last_seen_scan <> ?2",
                params![root_id, scan_id],
            )
            .map_err(|_| LibraryError::database())?;
        transaction
            .execute(
                "UPDATE media
                 SET is_available = CASE
                     WHEN EXISTS (
                         SELECT 1 FROM manual_imports WHERE manual_imports.media_id = media.id
                     ) OR EXISTS (
                         SELECT 1 FROM root_media WHERE root_media.media_id = media.id
                     ) THEN 1 ELSE 0 END,
                     updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')",
                [],
            )
            .map_err(|_| LibraryError::database())?;
        transaction.commit().map_err(|_| LibraryError::database())
    }

    pub(crate) fn contains_path(&self, path: &str) -> Result<bool, LibraryError> {
        let normalized_path = normalized_path_key(path);
        self.connection
            .query_row(
                "SELECT 1 FROM media WHERE normalized_path = ?1 AND is_available = 1",
                [normalized_path],
                |_| Ok(()),
            )
            .optional()
            .map(|result| result.is_some())
            .map_err(|_| LibraryError::database())
    }

    pub(crate) fn media_relocation_target(
        &self,
        media_id: &str,
    ) -> Result<MediaRelocationTarget, LibraryError> {
        if media_id.trim().is_empty() {
            return Err(LibraryError::new(
                "invalid-contract",
                "Media relocation requires a non-empty library media id.",
            ));
        }
        let target = self
            .connection
            .query_row(
                "SELECT kind, is_available FROM media WHERE id = ?1",
                [media_id],
                |row| Ok((row.get::<_, String>(0)?, row.get::<_, i64>(1)? == 1)),
            )
            .optional()
            .map_err(|_| LibraryError::database())?;
        let Some((kind, available)) = target else {
            return Err(LibraryError::new(
                "not-found",
                "The requested media item does not exist in the local library.",
            ));
        };
        if available {
            return Err(LibraryError::new(
                "invalid-contract",
                "Only unavailable library media can be relocated.",
            ));
        }
        let kind = match kind.as_str() {
            "audio" => LibraryMediaKind::Audio,
            "video" => LibraryMediaKind::Video,
            _ => return Err(LibraryError::database()),
        };
        Ok(MediaRelocationTarget { kind })
    }

    pub(crate) fn relocate_media(
        &mut self,
        media_id: &str,
        replacement: &LibraryIndexedItem,
    ) -> Result<LibrarySnapshot, LibraryError> {
        let replacement = validate_indexed_item(replacement)?;
        let transaction = self
            .connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(|_| LibraryError::database())?;
        let current = transaction
            .query_row(
                "SELECT kind, is_available FROM media WHERE id = ?1",
                [media_id],
                |row| Ok((row.get::<_, String>(0)?, row.get::<_, i64>(1)? == 1)),
            )
            .optional()
            .map_err(|_| LibraryError::database())?;
        let Some((current_kind, available)) = current else {
            return Err(LibraryError::new(
                "not-found",
                "The requested media item does not exist in the local library.",
            ));
        };
        if available {
            return Err(LibraryError::new(
                "invalid-contract",
                "Only unavailable library media can be relocated.",
            ));
        }
        if current_kind != replacement.kind.as_str() {
            return Err(LibraryError::new(
                "unsupported-media-kind",
                "The replacement file must have the same media kind as the original item.",
            ));
        }
        let conflicting_id = transaction
            .query_row(
                "SELECT id FROM media WHERE normalized_path = ?1 AND id <> ?2",
                params![replacement.normalized_path, media_id],
                |row| row.get::<_, String>(0),
            )
            .optional()
            .map_err(|_| LibraryError::database())?;
        if conflicting_id.is_some() {
            return Err(LibraryError::new(
                "path-conflict",
                "The replacement file is already represented by another library item.",
            ));
        }

        let changed = transaction
            .execute(
                "UPDATE media SET
                     path = ?2,
                     normalized_path = ?3,
                     title = ?4,
                     duration_ms = ?5,
                     is_available = 1,
                     metadata_status = ?6,
                     codec_name = ?7,
                     sample_rate_hz = ?8,
                     channel_count = ?9,
                     bits_per_sample = ?10,
                     file_size_bytes = ?11,
                     estimated_bit_rate_bps = ?12,
                     updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
                 WHERE id = ?1 AND is_available = 0",
                params![
                    media_id,
                    replacement.path,
                    replacement.normalized_path,
                    replacement.title,
                    replacement.duration_ms,
                    replacement.metadata_status.as_str(),
                    replacement.codec_name,
                    replacement.sample_rate_hz,
                    replacement.channels,
                    replacement.bits_per_sample,
                    replacement.file_size_bytes,
                    replacement.estimated_bit_rate_bps,
                ],
            )
            .map_err(|_| LibraryError::database())?;
        if changed != 1 {
            return Err(LibraryError::database());
        }
        transaction
            .execute(
                "INSERT INTO manual_imports (media_id)
                 VALUES (?1)
                 ON CONFLICT(media_id) DO UPDATE SET
                     selected_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')",
                [media_id],
            )
            .map_err(|_| LibraryError::database())?;
        transaction.commit().map_err(|_| LibraryError::database())?;
        self.snapshot()
    }

    pub(crate) fn media_probe_target(
        &self,
        media_id: &str,
    ) -> Result<MediaProbeTarget, LibraryError> {
        if media_id.trim().is_empty() {
            return Err(LibraryError::new(
                "invalid-contract",
                "Media details require a non-empty library media id.",
            ));
        }
        let target = self
            .connection
            .query_row(
                "SELECT path, is_available FROM media WHERE id = ?1",
                [media_id],
                |row| Ok((row.get::<_, String>(0)?, row.get::<_, i64>(1)? == 1)),
            )
            .optional()
            .map_err(|_| LibraryError::database())?;
        let Some((path, available)) = target else {
            return Err(LibraryError::new(
                "not-found",
                "The requested media item does not exist in the local library.",
            ));
        };
        if !available {
            return Err(LibraryError::new(
                "file-unavailable",
                "The requested media file is marked unavailable in the local library.",
            ));
        }
        Ok(MediaProbeTarget {
            media_id: media_id.to_owned(),
            path,
        })
    }

    pub(super) fn has_completed_legacy_import(&self) -> Result<bool, LibraryError> {
        self.connection
            .query_row(
                "SELECT 1 FROM import_history
                 WHERE source_kind = ?1 AND status = 'completed'
                 LIMIT 1",
                [LEGACY_IMPORT_KIND],
                |_| Ok(()),
            )
            .optional()
            .map(|result| result.is_some())
            .map_err(|_| LibraryError::database())
    }

    pub(super) fn import_legacy(
        &mut self,
        plan: &LegacyImportPlan,
        source_path: &str,
        backup_path: &str,
        fingerprint: &str,
    ) -> Result<(), LibraryError> {
        let transaction = self
            .connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(|_| LibraryError::database())?;
        let already_imported = transaction
            .query_row(
                "SELECT 1 FROM import_history
                 WHERE source_kind = ?1 AND status = 'completed'
                 LIMIT 1",
                [LEGACY_IMPORT_KIND],
                |_| Ok(()),
            )
            .optional()
            .map_err(|_| LibraryError::database())?
            .is_some();
        if already_imported {
            return Ok(());
        }

        for root in &plan.roots {
            transaction
                .execute(
                    "INSERT INTO library_roots (
                         path, normalized_path, recursive, include_video
                     ) VALUES (?1, ?2, ?3, ?4)
                     ON CONFLICT(normalized_path) DO UPDATE SET
                         recursive = excluded.recursive,
                         include_video = excluded.include_video",
                    params![
                        root.path,
                        root.normalized_path,
                        root.recursive,
                        root.include_video,
                    ],
                )
                .map_err(|_| LibraryError::database())?;
        }

        for media in &plan.media {
            let item = validate_import_item(&media.item)?;
            transaction
                .execute(
                    "INSERT INTO media (
                         id, path, normalized_path, title, kind, duration_ms, is_available
                     ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
                     ON CONFLICT(normalized_path) DO UPDATE SET
                         title = excluded.title,
                         kind = excluded.kind,
                         duration_ms = COALESCE(excluded.duration_ms, media.duration_ms),
                         is_available = MAX(media.is_available, excluded.is_available),
                         updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')",
                    params![
                        item.normalized_path,
                        item.path,
                        item.normalized_path,
                        item.title,
                        item.kind.as_str(),
                        item.duration_ms,
                        media.available,
                    ],
                )
                .map_err(|_| LibraryError::database())?;
            if media.manual {
                transaction
                    .execute(
                        "INSERT INTO manual_imports (media_id) VALUES (?1)
                         ON CONFLICT(media_id) DO NOTHING",
                        [&item.normalized_path],
                    )
                    .map_err(|_| LibraryError::database())?;
            }
            for root_key in &media.root_keys {
                transaction
                    .execute(
                        "INSERT INTO root_media (root_id, media_id, last_seen_scan)
                         SELECT id, ?1, 'flutter-v1-import'
                         FROM library_roots WHERE normalized_path = ?2
                         ON CONFLICT(root_id, media_id) DO UPDATE SET
                             last_seen_scan = excluded.last_seen_scan",
                        params![item.normalized_path, root_key],
                    )
                    .map_err(|_| LibraryError::database())?;
            }
        }

        for playlist in &plan.playlists {
            transaction
                .execute(
                    "INSERT INTO playlists (id, name, description)
                     VALUES (?1, ?2, ?3)
                     ON CONFLICT(id) DO UPDATE SET
                         name = excluded.name,
                         description = excluded.description,
                         updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')",
                    params![playlist.id, playlist.name, playlist.description],
                )
                .map_err(|_| LibraryError::database())?;
            transaction
                .execute(
                    "DELETE FROM playlist_items WHERE playlist_id = ?1",
                    [&playlist.id],
                )
                .map_err(|_| LibraryError::database())?;
            for (position, media_id) in playlist.media_ids.iter().enumerate() {
                let position = i64::try_from(position).map_err(|_| {
                    LibraryError::new(
                        "invalid-contract",
                        "The legacy playlist is too large to import safely.",
                    )
                })?;
                transaction
                    .execute(
                        "INSERT INTO playlist_items (playlist_id, media_id, position)
                         VALUES (?1, ?2, ?3)",
                        params![playlist.id, media_id, position],
                    )
                    .map_err(|_| LibraryError::database())?;
            }
        }

        for (key, value_json) in &plan.settings {
            transaction
                .execute(
                    "INSERT INTO settings (key, value_json)
                     VALUES (?1, ?2)
                     ON CONFLICT(key) DO UPDATE SET
                         value_json = excluded.value_json,
                         updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')",
                    params![key, value_json],
                )
                .map_err(|_| LibraryError::database())?;
        }

        let details = serde_json::json!({
            "mediaCount": plan.media.len(),
            "playlistCount": plan.playlists.len(),
            "rootCount": plan.roots.len(),
        })
        .to_string();
        transaction
            .execute(
                "INSERT INTO import_history (
                     source_kind, source_path, backup_path, status, details_json,
                     source_fingerprint
                 ) VALUES (?1, ?2, ?3, 'completed', ?4, ?5)",
                params![
                    LEGACY_IMPORT_KIND,
                    source_path,
                    backup_path,
                    details,
                    fingerprint,
                ],
            )
            .map_err(|_| LibraryError::database())?;

        transaction.commit().map_err(|_| LibraryError::database())
    }
}

#[derive(Clone, Copy)]
enum ImportSource<'a> {
    Manual,
    Root { root_id: i64, scan_id: &'a str },
}

struct ValidatedImport<'a> {
    path: &'a str,
    normalized_path: String,
    title: &'a str,
    kind: LibraryMediaKind,
    duration_ms: Option<i64>,
}

struct ValidatedIndexedImport<'a> {
    path: &'a str,
    normalized_path: String,
    title: &'a str,
    kind: LibraryMediaKind,
    duration_ms: Option<i64>,
    metadata_status: LibraryMetadataStatus,
    codec_name: Option<&'a str>,
    sample_rate_hz: Option<i64>,
    channels: Option<i64>,
    bits_per_sample: Option<i64>,
    file_size_bytes: Option<i64>,
    estimated_bit_rate_bps: Option<i64>,
}

fn validate_indexed_item(
    indexed: &LibraryIndexedItem,
) -> Result<ValidatedIndexedImport<'_>, LibraryError> {
    let item = validate_import_item(&indexed.item)?;
    let metadata = indexed.fast_metadata.as_ref();
    Ok(ValidatedIndexedImport {
        path: item.path,
        normalized_path: item.normalized_path,
        title: item.title,
        kind: item.kind,
        duration_ms: item.duration_ms,
        metadata_status: indexed.metadata_status,
        codec_name: metadata.and_then(|value| value.codec_name.as_deref()),
        sample_rate_hz: metadata
            .and_then(|value| value.sample_rate_hz)
            .map(i64::from),
        channels: metadata.and_then(|value| value.channels).map(i64::from),
        bits_per_sample: metadata
            .and_then(|value| value.bits_per_sample)
            .map(i64::from),
        file_size_bytes: checked_sqlite_integer(
            metadata.and_then(|value| value.file_size_bytes),
            "Media file size is outside the SQLite integer range.",
        )?,
        estimated_bit_rate_bps: checked_sqlite_integer(
            metadata.and_then(|value| value.estimated_bit_rate_bps),
            "Estimated media bit rate is outside the SQLite integer range.",
        )?,
    })
}

fn checked_sqlite_integer(value: Option<u64>, message: &str) -> Result<Option<i64>, LibraryError> {
    value
        .map(i64::try_from)
        .transpose()
        .map_err(|_| LibraryError::new("invalid-contract", message))
}

fn optional_u64(row: &rusqlite::Row<'_>, index: usize) -> rusqlite::Result<Option<u64>> {
    row.get::<_, Option<i64>>(index)?
        .map(u64::try_from)
        .transpose()
        .map_err(|error| {
            rusqlite::Error::FromSqlConversionFailure(
                index,
                rusqlite::types::Type::Integer,
                Box::new(error),
            )
        })
}

fn optional_u32(row: &rusqlite::Row<'_>, index: usize) -> rusqlite::Result<Option<u32>> {
    row.get::<_, Option<i64>>(index)?
        .map(u32::try_from)
        .transpose()
        .map_err(|error| {
            rusqlite::Error::FromSqlConversionFailure(
                index,
                rusqlite::types::Type::Integer,
                Box::new(error),
            )
        })
}

fn validate_import_item(item: &LibraryImportItem) -> Result<ValidatedImport<'_>, LibraryError> {
    if item.path.trim().is_empty() || item.title.trim().is_empty() {
        return Err(LibraryError::new(
            "invalid-contract",
            "Imported media must provide a non-empty path and title.",
        ));
    }
    let duration_ms = item
        .duration_ms
        .map(i64::try_from)
        .transpose()
        .map_err(|_| {
            LibraryError::new(
                "invalid-contract",
                "Imported media duration is outside the SQLite integer range.",
            )
        })?;

    Ok(ValidatedImport {
        path: &item.path,
        normalized_path: normalized_path_key(&item.path),
        title: &item.title,
        kind: item.kind,
        duration_ms,
    })
}

pub(crate) fn normalized_path_key(path: &str) -> String {
    path.replace('/', "\\").to_lowercase()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn audio(path: &str, title: &str) -> LibraryImportItem {
        LibraryImportItem {
            path: path.to_owned(),
            title: title.to_owned(),
            kind: LibraryMediaKind::Audio,
            duration_ms: Some(60_000),
        }
    }

    fn indexed_audio(path: &str, title: &str) -> LibraryIndexedItem {
        LibraryIndexedItem::pending(audio(path, title))
    }

    fn repository() -> LibraryRepository {
        LibraryRepository::from_connection(
            Connection::open_in_memory().expect("in-memory connection"),
        )
        .expect("repository")
    }

    #[test]
    fn import_is_idempotent_for_windows_path_case_and_separators() {
        let mut repository = repository();

        repository
            .import_files(&[audio(r"C:\Music\One.flac", "first title")])
            .expect("first import");
        let snapshot = repository
            .import_files(&[audio("c:/music/ONE.flac", "updated title")])
            .expect("retry import");

        assert_eq!(snapshot.items.len(), 1);
        assert_eq!(snapshot.items[0].path, r"C:\Music\One.flac");
        assert_eq!(snapshot.items[0].title, "updated title");
        assert!(repository
            .contains_path("c:/MUSIC/one.flac")
            .expect("contains query"));
    }

    #[test]
    fn invalid_item_rolls_back_the_whole_import() {
        let mut repository = repository();
        let invalid = audio("", "invalid");

        let error = repository
            .import_files(&[audio(r"C:\Music\One.flac", "one"), invalid])
            .expect_err("batch should fail");

        assert_eq!(error.code, "invalid-contract");
        assert!(repository.snapshot().expect("snapshot").items.is_empty());
    }

    #[test]
    fn persists_fast_metadata_without_erasing_it_on_a_pending_retry() {
        let mut repository = repository();
        let source = audio(r"C:\Music\One.flac", "one");
        repository
            .import_indexed_files(&[LibraryIndexedItem {
                item: source.clone(),
                metadata_status: LibraryMetadataStatus::Indexed,
                fast_metadata: Some(LibraryFastMetadata {
                    codec_name: Some("flac".to_owned()),
                    sample_rate_hz: Some(48_000),
                    channels: Some(2),
                    bits_per_sample: Some(24),
                    file_size_bytes: Some(4_096),
                    estimated_bit_rate_bps: Some(1_411_200),
                }),
            }])
            .expect("indexed import");
        repository
            .import_indexed_files(&[LibraryIndexedItem::pending(source)])
            .expect("pending retry");

        let item = repository
            .snapshot()
            .expect("snapshot")
            .items
            .into_iter()
            .next()
            .expect("media item");
        assert_eq!(item.metadata_status, LibraryMetadataStatus::Indexed);
        assert_eq!(
            item.fast_metadata.and_then(|metadata| metadata.codec_name),
            Some("flac".to_owned())
        );
    }

    #[test]
    fn scanned_files_and_roots_are_idempotent_without_becoming_manual_imports() {
        let mut repository = repository();
        let root_id = repository
            .register_root(r"C:\Music", true, true)
            .expect("first root");
        repository
            .register_root("c:/music", false, false)
            .expect("updated root");
        repository
            .import_scanned_files(
                root_id,
                "scan-1",
                &[indexed_audio(r"C:\Music\One.flac", "one")],
            )
            .expect("scanned file");

        let roots: i64 = repository
            .connection
            .query_row("SELECT COUNT(*) FROM library_roots", [], |row| row.get(0))
            .expect("root count");
        let manual: i64 = repository
            .connection
            .query_row("SELECT COUNT(*) FROM manual_imports", [], |row| row.get(0))
            .expect("manual count");

        assert_eq!(roots, 1);
        assert_eq!(manual, 0);
        assert_eq!(repository.snapshot().expect("snapshot").items.len(), 1);
    }

    #[test]
    fn completed_root_scan_marks_unseen_non_manual_media_unavailable() {
        let mut repository = repository();
        let root_id = repository
            .register_root(r"C:\Music", true, true)
            .expect("root");
        repository
            .import_scanned_files(
                root_id,
                "scan-1",
                &[
                    indexed_audio(r"C:\Music\One.flac", "one"),
                    indexed_audio(r"C:\Music\Two.flac", "two"),
                ],
            )
            .expect("first scan");
        repository
            .complete_root_scan(root_id, "scan-1")
            .expect("first reconcile");
        repository
            .import_scanned_files(
                root_id,
                "scan-2",
                &[indexed_audio(r"C:\Music\Two.flac", "two")],
            )
            .expect("second scan");
        repository
            .complete_root_scan(root_id, "scan-2")
            .expect("second reconcile");

        let snapshot = repository.snapshot().expect("snapshot");
        assert_eq!(snapshot.items.len(), 2);
        assert!(!snapshot.items[0].available);
        assert!(snapshot.items[1].available);
    }

    #[test]
    fn relocation_preserves_identity_playlist_references_and_future_imports() {
        let mut repository = repository();
        let old_path = r"C:\Music\Missing.flac";
        let new_path = r"D:\Recovered\Found.flac";
        let root_id = repository
            .register_root(r"C:\Music", true, false)
            .expect("root");
        repository
            .import_scanned_files(
                root_id,
                "scan-1",
                &[indexed_audio(old_path, "Missing.flac")],
            )
            .expect("initial scan");
        repository
            .complete_root_scan(root_id, "scan-1")
            .expect("initial reconcile");
        repository
            .create_playlist(
                "playlist-one",
                &crate::library::contracts::PlaylistCreateRequest {
                    name: "保留引用".to_owned(),
                    description: String::new(),
                },
            )
            .expect("playlist");
        let media_id = normalized_path_key(old_path);
        repository
            .add_playlist_items(&crate::library::contracts::PlaylistItemsRequest {
                playlist_id: "playlist-one".to_owned(),
                media_ids: vec![media_id.clone()],
            })
            .expect("playlist item");
        repository
            .complete_root_scan(root_id, "scan-2")
            .expect("mark missing");

        let relocated = repository
            .relocate_media(&media_id, &indexed_audio(new_path, "Found.flac"))
            .expect("relocate");

        assert_eq!(relocated.items[0].id, media_id);
        assert_eq!(relocated.items[0].path, new_path);
        assert_eq!(relocated.items[0].title, "Found.flac");
        assert!(relocated.items[0].available);
        assert_eq!(
            relocated.playlists[0].item_ids.as_slice(),
            std::slice::from_ref(&media_id)
        );

        let reimported = repository
            .import_files(&[audio(new_path, "Found again.flac")])
            .expect("manual reimport");
        assert_eq!(reimported.items.len(), 1);
        assert_eq!(reimported.items[0].id, media_id);
        assert_eq!(reimported.items[0].title, "Found again.flac");
    }

    #[test]
    fn relocation_rejects_a_path_owned_by_another_item_without_partial_changes() {
        let mut repository = repository();
        let missing_path = r"C:\Music\Missing.flac";
        let existing_path = r"D:\Music\Existing.flac";
        repository
            .import_files(&[
                audio(missing_path, "Missing.flac"),
                audio(existing_path, "Existing.flac"),
            ])
            .expect("imports");
        repository
            .connection
            .execute(
                "UPDATE media SET is_available = 0 WHERE id = ?1",
                [normalized_path_key(missing_path)],
            )
            .expect("mark missing");

        let error = repository
            .relocate_media(
                &normalized_path_key(missing_path),
                &indexed_audio(existing_path, "Existing.flac"),
            )
            .expect_err("conflicting path");

        assert_eq!(error.code, "path-conflict");
        let snapshot = repository.snapshot().expect("snapshot");
        assert_eq!(snapshot.items.len(), 2);
        assert!(snapshot.items.iter().any(|item| {
            item.id == normalized_path_key(missing_path)
                && item.path == missing_path
                && !item.available
        }));
    }
}
