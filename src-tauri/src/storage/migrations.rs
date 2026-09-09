use rusqlite::{params, Connection, OptionalExtension, Result, TransactionBehavior};

const INITIAL_SCHEMA_VERSION: i64 = 1;
const LEGACY_IMPORT_SCHEMA_VERSION: i64 = 2;
const FAST_METADATA_SCHEMA_VERSION: i64 = 3;

const INITIAL_SCHEMA: &str = r#"
CREATE TABLE media (
    id              TEXT PRIMARY KEY NOT NULL,
    path            TEXT NOT NULL,
    normalized_path TEXT NOT NULL UNIQUE,
    title           TEXT NOT NULL,
    kind            TEXT NOT NULL CHECK (kind IN ('audio', 'video')),
    duration_ms     INTEGER CHECK (duration_ms IS NULL OR duration_ms >= 0),
    is_available    INTEGER NOT NULL DEFAULT 1 CHECK (is_available IN (0, 1)),
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
) STRICT;

CREATE TABLE library_roots (
    id              INTEGER PRIMARY KEY,
    path            TEXT NOT NULL,
    normalized_path TEXT NOT NULL UNIQUE,
    recursive       INTEGER NOT NULL DEFAULT 1 CHECK (recursive IN (0, 1)),
    include_video   INTEGER NOT NULL DEFAULT 1 CHECK (include_video IN (0, 1)),
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
) STRICT;

CREATE TABLE manual_imports (
    media_id    TEXT PRIMARY KEY NOT NULL REFERENCES media(id) ON DELETE CASCADE,
    selected_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
) STRICT;

CREATE TABLE root_media (
    root_id        INTEGER NOT NULL REFERENCES library_roots(id) ON DELETE CASCADE,
    media_id       TEXT NOT NULL REFERENCES media(id) ON DELETE CASCADE,
    last_seen_scan TEXT NOT NULL,
    PRIMARY KEY (root_id, media_id)
) STRICT;

CREATE TABLE playlists (
    id          TEXT PRIMARY KEY NOT NULL,
    name        TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
) STRICT;

CREATE TABLE playlist_items (
    playlist_id TEXT NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
    media_id    TEXT NOT NULL REFERENCES media(id) ON DELETE RESTRICT,
    position    INTEGER NOT NULL CHECK (position >= 0),
    PRIMARY KEY (playlist_id, media_id),
    UNIQUE (playlist_id, position)
) STRICT;

CREATE TABLE settings (
    key        TEXT PRIMARY KEY NOT NULL,
    value_json TEXT NOT NULL,
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
) STRICT;

CREATE TABLE import_history (
    id           INTEGER PRIMARY KEY,
    source_kind  TEXT NOT NULL,
    source_path  TEXT,
    backup_path  TEXT,
    status       TEXT NOT NULL CHECK (status IN ('started', 'completed', 'failed')),
    details_json TEXT,
    imported_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
) STRICT;
"#;

const LEGACY_IMPORT_SCHEMA: &str = r#"
ALTER TABLE import_history ADD COLUMN source_fingerprint TEXT;

CREATE UNIQUE INDEX completed_import_source_once
ON import_history(source_kind)
WHERE status = 'completed';
"#;

const FAST_METADATA_SCHEMA: &str = r#"
ALTER TABLE media ADD COLUMN metadata_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (metadata_status IN ('pending', 'indexed', 'failed'));
ALTER TABLE media ADD COLUMN codec_name TEXT;
ALTER TABLE media ADD COLUMN sample_rate_hz INTEGER
    CHECK (sample_rate_hz IS NULL OR sample_rate_hz > 0);
ALTER TABLE media ADD COLUMN channel_count INTEGER
    CHECK (channel_count IS NULL OR channel_count > 0);
ALTER TABLE media ADD COLUMN bits_per_sample INTEGER
    CHECK (bits_per_sample IS NULL OR bits_per_sample > 0);
ALTER TABLE media ADD COLUMN file_size_bytes INTEGER
    CHECK (file_size_bytes IS NULL OR file_size_bytes >= 0);
ALTER TABLE media ADD COLUMN estimated_bit_rate_bps INTEGER
    CHECK (estimated_bit_rate_bps IS NULL OR estimated_bit_rate_bps >= 0);
"#;

pub(crate) fn apply(connection: &mut Connection) -> Result<()> {
    connection.execute_batch(
        "PRAGMA foreign_keys = ON;
         PRAGMA journal_mode = WAL;
         PRAGMA synchronous = NORMAL;",
    )?;
    connection.busy_timeout(std::time::Duration::from_secs(5))?;
    connection.execute_batch(
        "CREATE TABLE IF NOT EXISTS schema_migrations (
             version    INTEGER PRIMARY KEY NOT NULL,
             name       TEXT NOT NULL,
             applied_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
         ) STRICT;",
    )?;

    apply_migration(
        connection,
        INITIAL_SCHEMA_VERSION,
        "initial-library-schema",
        INITIAL_SCHEMA,
    )?;
    apply_migration(
        connection,
        LEGACY_IMPORT_SCHEMA_VERSION,
        "legacy-import-fingerprint",
        LEGACY_IMPORT_SCHEMA,
    )?;
    apply_migration(
        connection,
        FAST_METADATA_SCHEMA_VERSION,
        "fast-media-metadata",
        FAST_METADATA_SCHEMA,
    )
}

fn apply_migration(connection: &mut Connection, version: i64, name: &str, sql: &str) -> Result<()> {
    let already_applied = connection
        .query_row(
            "SELECT 1 FROM schema_migrations WHERE version = ?1",
            [version],
            |_| Ok(()),
        )
        .optional()?
        .is_some();
    if already_applied {
        return Ok(());
    }

    let transaction = connection.transaction_with_behavior(TransactionBehavior::Immediate)?;
    transaction.execute_batch(sql)?;
    transaction.execute(
        "INSERT INTO schema_migrations (version, name) VALUES (?1, ?2)",
        params![version, name],
    )?;
    transaction.commit()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn initial_migration_is_idempotent_and_creates_required_tables() {
        let mut connection = Connection::open_in_memory().expect("in-memory database");

        apply(&mut connection).expect("first migration");
        apply(&mut connection).expect("repeated migration");

        for table in [
            "media",
            "library_roots",
            "manual_imports",
            "root_media",
            "playlists",
            "playlist_items",
            "settings",
            "schema_migrations",
            "import_history",
        ] {
            let exists: i64 = connection
                .query_row(
                    "SELECT COUNT(*) FROM sqlite_schema WHERE type = 'table' AND name = ?1",
                    [table],
                    |row| row.get(0),
                )
                .expect("table query");
            assert_eq!(exists, 1, "missing table: {table}");
        }

        let versions: i64 = connection
            .query_row("SELECT COUNT(*) FROM schema_migrations", [], |row| {
                row.get(0)
            })
            .expect("migration count");
        assert_eq!(versions, 3);

        let fingerprint_column: i64 = connection
            .query_row(
                "SELECT COUNT(*) FROM pragma_table_info('import_history') WHERE name = 'source_fingerprint'",
                [],
                |row| row.get(0),
            )
            .expect("fingerprint column");
        assert_eq!(fingerprint_column, 1);

        for column in [
            "metadata_status",
            "codec_name",
            "sample_rate_hz",
            "channel_count",
            "bits_per_sample",
            "file_size_bytes",
            "estimated_bit_rate_bps",
        ] {
            let exists: i64 = connection
                .query_row(
                    "SELECT COUNT(*) FROM pragma_table_info('media') WHERE name = ?1",
                    [column],
                    |row| row.get(0),
                )
                .expect("metadata column");
            assert_eq!(exists, 1, "missing media metadata column: {column}");
        }
    }
}
