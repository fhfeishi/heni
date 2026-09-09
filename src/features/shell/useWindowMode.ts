import { useEffect, useState } from "react";

import type {
  WindowError,
  WindowMode,
  WindowPort,
  WindowSnapshot,
} from "../../contracts/window";

export interface WindowModeController {
  mode: WindowMode;
  snapshot: WindowSnapshot | null;
  available: boolean;
  busy: boolean;
  error: WindowError | null;
  setMode(mode: WindowMode): Promise<boolean>;
  clearError(): void;
}

export const useWindowMode = (port: WindowPort): WindowModeController => {
  const [snapshot, setSnapshot] = useState<WindowSnapshot | null>(null);
  const [available, setAvailable] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<WindowError | null>(null);

  useEffect(() => {
    let active = true;
    void port.read().then((result) => {
      if (!active) {
        return;
      }
      if (result.ok) {
        setSnapshot(result.value);
        setAvailable(true);
      } else {
        setAvailable(false);
      }
    });
    return () => {
      active = false;
    };
  }, [port]);

  const setMode = async (mode: WindowMode): Promise<boolean> => {
    if (!available || busy || snapshot?.mode === mode) {
      return snapshot?.mode === mode;
    }
    setBusy(true);
    setError(null);
    const result = await port.setMode(mode);
    setBusy(false);
    if (!result.ok) {
      setError(result.error);
      return false;
    }
    setSnapshot(result.value);
    return true;
  };

  return {
    mode: snapshot?.mode ?? "main",
    snapshot,
    available,
    busy,
    error,
    setMode,
    clearError: () => setError(null),
  };
};
