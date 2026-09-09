import { useCallback, useRef, useState } from "react";

import type {
  LibraryError,
  LibraryPort,
  MediaDetails,
} from "../../contracts/library";

export interface MediaDetailsViewState {
  details: MediaDetails | null;
  error: LibraryError | null;
  loadingMediaId: string | null;
  inspect(mediaId: string): Promise<boolean>;
  close(): void;
}

export const useMediaDetails = (port: LibraryPort): MediaDetailsViewState => {
  const [details, setDetails] = useState<MediaDetails | null>(null);
  const [error, setError] = useState<LibraryError | null>(null);
  const [loadingMediaId, setLoadingMediaId] = useState<string | null>(null);
  const requestEpoch = useRef(0);

  const inspect = useCallback(
    async (mediaId: string): Promise<boolean> => {
      const epoch = ++requestEpoch.current;
      setLoadingMediaId(mediaId);
      setDetails(null);
      setError(null);
      const result = await port.readMediaDetails(mediaId);
      if (requestEpoch.current !== epoch) {
        return false;
      }
      setLoadingMediaId(null);
      if (result.ok) {
        setDetails(result.value);
        return true;
      }
      setError(result.error);
      return false;
    },
    [port],
  );

  const close = useCallback(() => {
    requestEpoch.current += 1;
    setLoadingMediaId(null);
    setDetails(null);
    setError(null);
  }, []);

  return { details, error, loadingMediaId, inspect, close };
};
