import { useCallback, useEffect, useRef, useState } from "react";

import {
  defaultSettingsSnapshot,
  type SettingsError,
  type SettingsPort,
  type SettingsSnapshot,
  type SettingsUpdate,
} from "../../contracts/settings";

export interface SettingsViewState {
  snapshot: SettingsSnapshot;
  loading: boolean;
  busy: boolean;
  error: SettingsError | null;
  update(request: SettingsUpdate): Promise<boolean>;
  clearError(): void;
}

export const useSettings = (port: SettingsPort): SettingsViewState => {
  const [snapshot, setSnapshot] = useState(defaultSettingsSnapshot);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<SettingsError | null>(null);
  const mutationEpoch = useRef(0);

  useEffect(() => {
    let active = true;
    const startedAtEpoch = mutationEpoch.current;
    void port.read().then((result) => {
      if (!active || mutationEpoch.current !== startedAtEpoch) {
        return;
      }
      setLoading(false);
      if (result.ok) {
        setSnapshot(result.value);
      } else {
        setError(result.error);
      }
    });
    return () => {
      active = false;
    };
  }, [port]);

  const update = useCallback(
    async (request: SettingsUpdate): Promise<boolean> => {
      mutationEpoch.current += 1;
      setBusy(true);
      setError(null);
      const result = await port.update(request);
      setBusy(false);
      setLoading(false);
      if (!result.ok) {
        setError(result.error);
        return false;
      }
      setSnapshot(result.value);
      return true;
    },
    [port],
  );

  return {
    snapshot,
    loading,
    busy,
    error,
    update,
    clearError: () => setError(null),
  };
};
