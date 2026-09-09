use std::collections::HashSet;

use rusqlite::{params, OptionalExtension, Transaction, TransactionBehavior};

use super::{
    contracts::{
        LibraryError, LibraryPlaylist, LibrarySnapshot, PlaylistCreateRequest,
        PlaylistItemsRequest, PlaylistUpdateRequest,
    },
    repository::LibraryRepository,
};

const MAX_PLAYLIST_NAME_CHARS: usize = 100;
const MAX_PLAYLIST_DESCRIPTION_CHARS: usize = 1_000;
const MAX_PLAYLIST_ITEMS_PER_MUTATION: usize = 10_000;

impl LibraryRepository {
    pub(super) fn playlist_snapshot(&self) -> Result<Vec<LibraryPlaylist>, LibraryError> {
        let mut statement = self
            .connection
            .prepare(
                "SELECT id, name, description
                 FROM playlists
                 ORDER BY created_at, id",
            )
            .map_err(|_| LibraryError::database())?;
        let playlists = statement
            .query_map([], |row| {
                Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, String>(2)?,
                ))
            })
            .map_err(|_| LibraryError::database())?
            .collect::<Result<Vec<_>, _>>()
            .map_err(|_| LibraryError::database())?;

        playlists
            .into_iter()
            .map(|(id, name, description)| {
                Ok(LibraryPlaylist {
                    item_ids: read_playlist_item_ids(&self.connection, &id)?,
                    id,
                    name,
                    description,
                })
            })
            .collect()
    }

    pub(crate) fn create_playlist(
        &mut self,
        playlist_id: &str,
        request: &PlaylistCreateRequest,
    ) -> Result<LibrarySnapshot, LibraryError> {
        validate_playlist_id(playlist_id)?;
        let name = validate_name(&request.name)?;
        let description = validate_description(&request.description)?;
        self.connection
            .execute(
                "INSERT INTO playlists (id, name, description) VALUES (?1, ?2, ?3)",
                params![playlist_id, name, description],
            )
            .map_err(|_| LibraryError::database())?;
        self.snapshot()
    }

    pub(crate) fn update_playlist(
        &mut self,
        request: &PlaylistUpdateRequest,
    ) -> Result<LibrarySnapshot, LibraryError> {
        validate_playlist_id(&request.playlist_id)?;
        let name = validate_name(&request.name)?;
        let description = validate_description(&request.description)?;
        let changed = self
            .connection
            .execute(
                "UPDATE playlists
                 SET name = ?2,
                     description = ?3,
                     updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
                 WHERE id = ?1",
                params![request.playlist_id, name, description],
            )
            .map_err(|_| LibraryError::database())?;
        if changed == 0 {
            return Err(playlist_not_found());
        }
        self.snapshot()
    }

    pub(crate) fn delete_playlist(
        &mut self,
        playlist_id: &str,
    ) -> Result<LibrarySnapshot, LibraryError> {
        validate_playlist_id(playlist_id)?;
        let transaction = self
            .connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(|_| LibraryError::database())?;
        let changed = transaction
            .execute("DELETE FROM playlists WHERE id = ?1", [playlist_id])
            .map_err(|_| LibraryError::database())?;
        if changed == 0 {
            return Err(playlist_not_found());
        }
        transaction.commit().map_err(|_| LibraryError::database())?;
        self.snapshot()
    }

    pub(crate) fn add_playlist_items(
        &mut self,
        request: &PlaylistItemsRequest,
    ) -> Result<LibrarySnapshot, LibraryError> {
        validate_playlist_items_request(request)?;
        let requested = unique_ids(&request.media_ids);
        let transaction = self
            .connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(|_| LibraryError::database())?;
        require_playlist(&transaction, &request.playlist_id)?;
        require_media(&transaction, &requested)?;

        let mut next = read_playlist_item_ids(&transaction, &request.playlist_id)?;
        let mut seen = next.iter().cloned().collect::<HashSet<_>>();
        next.extend(requested.into_iter().filter(|id| seen.insert(id.clone())));
        rewrite_playlist_items(&transaction, &request.playlist_id, &next)?;
        transaction.commit().map_err(|_| LibraryError::database())?;
        self.snapshot()
    }

    pub(crate) fn remove_playlist_items(
        &mut self,
        request: &PlaylistItemsRequest,
    ) -> Result<LibrarySnapshot, LibraryError> {
        validate_playlist_items_request(request)?;
        let removals = unique_ids(&request.media_ids)
            .into_iter()
            .collect::<HashSet<_>>();
        let transaction = self
            .connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(|_| LibraryError::database())?;
        require_playlist(&transaction, &request.playlist_id)?;

        let mut next = read_playlist_item_ids(&transaction, &request.playlist_id)?;
        next.retain(|id| !removals.contains(id));
        rewrite_playlist_items(&transaction, &request.playlist_id, &next)?;
        transaction.commit().map_err(|_| LibraryError::database())?;
        self.snapshot()
    }
}

fn read_playlist_item_ids(
    connection: &rusqlite::Connection,
    playlist_id: &str,
) -> Result<Vec<String>, LibraryError> {
    let mut statement = connection
        .prepare(
            "SELECT media_id
             FROM playlist_items
             WHERE playlist_id = ?1
             ORDER BY position",
        )
        .map_err(|_| LibraryError::database())?;
    let item_ids = statement
        .query_map([playlist_id], |row| row.get(0))
        .map_err(|_| LibraryError::database())?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|_| LibraryError::database())?;
    Ok(item_ids)
}

fn rewrite_playlist_items(
    transaction: &Transaction<'_>,
    playlist_id: &str,
    media_ids: &[String],
) -> Result<(), LibraryError> {
    transaction
        .execute(
            "DELETE FROM playlist_items WHERE playlist_id = ?1",
            [playlist_id],
        )
        .map_err(|_| LibraryError::database())?;
    for (position, media_id) in media_ids.iter().enumerate() {
        let position = i64::try_from(position).map_err(|_| invalid_contract())?;
        transaction
            .execute(
                "INSERT INTO playlist_items (playlist_id, media_id, position)
                 VALUES (?1, ?2, ?3)",
                params![playlist_id, media_id, position],
            )
            .map_err(|_| LibraryError::database())?;
    }
    Ok(())
}

fn require_playlist(transaction: &Transaction<'_>, playlist_id: &str) -> Result<(), LibraryError> {
    let exists = transaction
        .query_row(
            "SELECT 1 FROM playlists WHERE id = ?1",
            [playlist_id],
            |_| Ok(()),
        )
        .optional()
        .map_err(|_| LibraryError::database())?
        .is_some();
    if exists {
        Ok(())
    } else {
        Err(playlist_not_found())
    }
}

fn require_media(transaction: &Transaction<'_>, media_ids: &[String]) -> Result<(), LibraryError> {
    for media_id in media_ids {
        let exists = transaction
            .query_row("SELECT 1 FROM media WHERE id = ?1", [media_id], |_| Ok(()))
            .optional()
            .map_err(|_| LibraryError::database())?
            .is_some();
        if !exists {
            return Err(LibraryError::new(
                "not-found",
                "One or more selected library items no longer exist.",
            ));
        }
    }
    Ok(())
}

fn validate_playlist_items_request(request: &PlaylistItemsRequest) -> Result<(), LibraryError> {
    validate_playlist_id(&request.playlist_id)?;
    if request.media_ids.len() > MAX_PLAYLIST_ITEMS_PER_MUTATION
        || request.media_ids.iter().any(|id| id.trim().is_empty())
    {
        return Err(invalid_contract());
    }
    Ok(())
}

fn validate_playlist_id(value: &str) -> Result<(), LibraryError> {
    if value.trim().is_empty() || value.chars().count() > 200 {
        Err(invalid_contract())
    } else {
        Ok(())
    }
}

fn validate_name(value: &str) -> Result<&str, LibraryError> {
    let value = value.trim();
    if value.is_empty() || value.chars().count() > MAX_PLAYLIST_NAME_CHARS {
        Err(invalid_contract())
    } else {
        Ok(value)
    }
}

fn validate_description(value: &str) -> Result<&str, LibraryError> {
    let value = value.trim();
    if value.chars().count() > MAX_PLAYLIST_DESCRIPTION_CHARS {
        Err(invalid_contract())
    } else {
        Ok(value)
    }
}

fn unique_ids(values: &[String]) -> Vec<String> {
    let mut seen = HashSet::new();
    values
        .iter()
        .filter(|id| seen.insert((*id).clone()))
        .cloned()
        .collect()
}

fn invalid_contract() -> LibraryError {
    LibraryError::new(
        "invalid-contract",
        "Playlist names, descriptions, and selected items must stay within the supported limits.",
    )
}

fn playlist_not_found() -> LibraryError {
    LibraryError::new("not-found", "The selected playlist no longer exists.")
}

#[cfg(test)]
mod tests {
    use rusqlite::Connection;

    use super::*;
    use crate::library::contracts::{LibraryImportItem, LibraryMediaKind};
    use crate::library::repository::normalized_path_key;

    #[test]
    fn creates_updates_and_deletes_a_trimmed_playlist() {
        let mut repository = repository();
        let created = repository
            .create_playlist(
                "playlist-one",
                &PlaylistCreateRequest {
                    name: "  通勤  ".to_owned(),
                    description: "  早晚路上  ".to_owned(),
                },
            )
            .expect("create");

        assert_eq!(created.playlists[0].name, "通勤");
        assert_eq!(created.playlists[0].description, "早晚路上");

        let updated = repository
            .update_playlist(&PlaylistUpdateRequest {
                playlist_id: "playlist-one".to_owned(),
                name: "夜跑".to_owned(),
                description: "  晚上散步和跑步听  ".to_owned(),
            })
            .expect("update");
        assert_eq!(updated.playlists[0].name, "夜跑");
        assert_eq!(updated.playlists[0].description, "晚上散步和跑步听");

        let deleted = repository.delete_playlist("playlist-one").expect("delete");
        assert!(deleted.playlists.is_empty());
    }

    #[test]
    fn batch_add_is_ordered_and_idempotent_then_remove_resequences() {
        let mut repository = repository_with_media();
        repository
            .create_playlist(
                "playlist-one",
                &PlaylistCreateRequest {
                    name: "精选".to_owned(),
                    description: String::new(),
                },
            )
            .expect("create");
        let one = normalized_path_key(r"C:\Music\One.flac");
        let two = normalized_path_key(r"C:\Music\Two.flac");

        let added = repository
            .add_playlist_items(&PlaylistItemsRequest {
                playlist_id: "playlist-one".to_owned(),
                media_ids: vec![one.clone(), one.clone(), two.clone()],
            })
            .expect("add");
        assert_eq!(added.playlists[0].item_ids, [one.clone(), two.clone()]);

        let repeated = repository
            .add_playlist_items(&PlaylistItemsRequest {
                playlist_id: "playlist-one".to_owned(),
                media_ids: vec![two.clone(), one.clone()],
            })
            .expect("idempotent add");
        assert_eq!(repeated.playlists[0].item_ids, [one.clone(), two.clone()]);

        let removed = repository
            .remove_playlist_items(&PlaylistItemsRequest {
                playlist_id: "playlist-one".to_owned(),
                media_ids: vec![one],
            })
            .expect("remove");
        assert_eq!(removed.playlists[0].item_ids, [two]);
        let positions = repository
            .connection
            .prepare("SELECT position FROM playlist_items ORDER BY position")
            .expect("positions statement")
            .query_map([], |row| row.get::<_, i64>(0))
            .expect("positions query")
            .collect::<Result<Vec<_>, _>>()
            .expect("positions");
        assert_eq!(positions, [0]);
        assert_eq!(removed.items.len(), 2);
    }

    #[test]
    fn missing_media_rolls_back_the_whole_batch() {
        let mut repository = repository_with_media();
        repository
            .create_playlist(
                "playlist-one",
                &PlaylistCreateRequest {
                    name: "精选".to_owned(),
                    description: String::new(),
                },
            )
            .expect("create");

        let error = repository
            .add_playlist_items(&PlaylistItemsRequest {
                playlist_id: "playlist-one".to_owned(),
                media_ids: vec![
                    normalized_path_key(r"C:\Music\One.flac"),
                    "missing-media".to_owned(),
                ],
            })
            .expect_err("missing media");

        assert_eq!(error.code, "not-found");
        assert!(repository.snapshot().expect("snapshot").playlists[0]
            .item_ids
            .is_empty());
    }

    fn repository() -> LibraryRepository {
        LibraryRepository::from_connection(
            Connection::open_in_memory().expect("in-memory connection"),
        )
        .expect("repository")
    }

    fn repository_with_media() -> LibraryRepository {
        let mut repository = repository();
        repository
            .import_files(&[
                audio(r"C:\Music\One.flac", "One"),
                audio(r"C:\Music\Two.flac", "Two"),
            ])
            .expect("media");
        repository
    }

    fn audio(path: &str, title: &str) -> LibraryImportItem {
        LibraryImportItem {
            path: path.to_owned(),
            title: title.to_owned(),
            kind: LibraryMediaKind::Audio,
            duration_ms: None,
        }
    }
}
