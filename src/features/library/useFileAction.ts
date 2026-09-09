import { useCallback, useState } from "react";

import type {
  FileActionError,
  FileActionPort,
} from "../../contracts/fileAction";

export interface FileActionViewState {
  busyMediaId: string | null;
  error: FileActionError | null;
  revealMedia(mediaId: string): Promise<boolean>;
  clearError(): void;
}

export const useFileAction = (port: FileActionPort): FileActionViewState => {
  const [busyMediaId, setBusyMediaId] = useState<string | null>(null);
  const [error, setError] = useState<FileActionError | null>(null);

  const revealMedia = useCallback(
    async (mediaId: string): Promise<boolean> => {
      setBusyMediaId(mediaId);
      setError(null);
      const result = await port.revealMedia(mediaId);
      setBusyMediaId(null);
      if (result.ok) {
        return true;
      }
      setError(result.error);
      return false;
    },
    [port],
  );

  return {
    busyMediaId,
    error,
    revealMedia,
    clearError: () => setError(null),
  };
};
