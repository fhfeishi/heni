import { useCallback, useEffect, useRef, useState } from "react";
import { useSceneryRotation } from "./useSceneryRotation";

import {
  emptyScenery,
  type SceneryError,
  type SceneryPort,
  type ScenerySnapshot,
} from "../../contracts/scenery";

export const useScenery = (port: SceneryPort, autoRotate = false) => {
  const [snapshot, setSnapshot] = useState<ScenerySnapshot>(emptyScenery);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<SceneryError | null>(null);
  const lifecycle = useRef(0);
  const operationBusy = useRef(true);

  useEffect(() => {
    const epoch = ++lifecycle.current;
    operationBusy.current = true;
    void port.read().then((result) => {
      if (lifecycle.current !== epoch) return;
      operationBusy.current = false;
      setLoading(false);
      setBusy(false);
      if (result.ok) {
        setSnapshot(result.value);
        setError(null);
      } else {
        setSnapshot(emptyScenery);
        setError(result.error);
      }
    });
    return () => {
      lifecycle.current += 1;
    };
  }, [port]);

  const mutate = useCallback(
    async (action: "choose" | "clear" | "next" | "previous") => {
      if ((action === "next" || action === "previous") && port.step === undefined) return false;
      // Guard synchronously: React's next render is too late for a double click.
      if (operationBusy.current) return false;
      operationBusy.current = true;
      const epoch = lifecycle.current;
      setBusy(true);
      setError(null);
      const result = action === "choose" || action === "clear"
        ? await port[action]()
        : await port.step?.(action === "next");
      if (lifecycle.current !== epoch) return false;
      operationBusy.current = false;
      setBusy(false);
      if (result === undefined) return false;
      if (!result.ok) {
        setError(result.error);
        return false;
      }
      if (result.value !== null) setSnapshot(result.value);
      return true;
    },
    [port],
  );

  const reportImageFailure = useCallback((imageUrl: string) => {
    setSnapshot((current) =>
      current.state === "ready" && current.dataUrl === imageUrl
        ? {
            state: "unavailable",
            fileName: current.fileName,
            reason: "unsupported-image",
            ...(current.collection === undefined ? {} : { collection: current.collection }),
          }
        : current,
    );
  }, []);

  const next = useCallback(() => mutate("next"), [mutate]);
  const canStep = port.step !== undefined && snapshot.state !== "empty" && (snapshot.collection?.count ?? 1) > 1;
  useSceneryRotation(autoRotate && canStep && !loading && !busy && error === null && snapshot.state === "ready", next);

  return {
    snapshot,
    loading,
    busy,
    error,
    imageUrl: snapshot.state === "ready" ? snapshot.dataUrl : null,
    choose: () => mutate("choose"),
    clear: () => mutate("clear"),
    canStep,
    next,
    previous: () => mutate("previous"),
    reportImageFailure,
  };
};
