import { useState } from "react";

import type { LibraryPlaylist } from "../../contracts/library";

export interface PlaylistMetadataFormProps {
  playlist: LibraryPlaylist;
  busy: boolean;
  onUpdate(
    playlistId: string,
    name: string,
    description: string,
  ): Promise<boolean>;
  onDelete(playlistId: string): Promise<boolean>;
  onCancel(): void;
}

export const PlaylistMetadataForm = ({
  playlist,
  busy,
  onUpdate,
  onDelete,
  onCancel,
}: PlaylistMetadataFormProps) => {
  const [name, setName] = useState(playlist.name);
  const [description, setDescription] = useState(playlist.description);
  const [deleteConfirmation, setDeleteConfirmation] = useState(false);

  const save = async () => {
    const trimmedName = name.trim();
    const trimmedDescription = description.trim();
    if (trimmedName === "") {
      return;
    }
    if (await onUpdate(playlist.id, trimmedName, trimmedDescription)) {
      setName(trimmedName);
      setDescription(trimmedDescription);
    }
  };

  return (
    <form
      className="playlist-metadata"
      onSubmit={(event) => {
        event.preventDefault();
        void save();
      }}
    >
      <label>
        名称
        <input
          value={name}
          maxLength={100}
          disabled={busy}
          onChange={(event) => setName(event.currentTarget.value)}
        />
      </label>
      <label>
        说明
        <textarea
          value={description}
          maxLength={1_000}
          disabled={busy}
          onChange={(event) => setDescription(event.currentTarget.value)}
        />
      </label>
      <div className="playlist-metadata__actions">
        <button type="submit" disabled={busy || name.trim() === ""}>
          保存歌单
        </button>
        <button type="button" disabled={busy} onClick={onCancel}>
          取消编辑
        </button>
        {!deleteConfirmation ? (
          <button
            type="button"
            className="danger-button"
            disabled={busy}
            onClick={() => setDeleteConfirmation(true)}
          >
            删除歌单
          </button>
        ) : (
          <div className="playlist-delete-confirmation" role="alert">
            <span>确定删除？曲库文件不会受影响。</span>
            <button
              type="button"
              disabled={busy}
              onClick={() => setDeleteConfirmation(false)}
            >
              保留歌单
            </button>
            <button
              type="button"
              className="danger-button"
              disabled={busy}
              onClick={() => {
                void onDelete(playlist.id).then((deleted) => {
                  if (!deleted) {
                    setDeleteConfirmation(false);
                  }
                });
              }}
            >
              确认删除歌单
            </button>
          </div>
        )}
      </div>
    </form>
  );
};
