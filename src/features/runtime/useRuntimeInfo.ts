import { useEffect, useState } from "react";

import type {
  RuntimeInfo,
  RuntimeInfoError,
  RuntimeInfoPort,
} from "../../contracts/runtime";

export type RuntimeInfoViewState =
  | Readonly<{ status: "loading" }>
  | Readonly<{ status: "ready"; info: RuntimeInfo }>
  | Readonly<{ status: "failed"; error: RuntimeInfoError }>;

export const useRuntimeInfo = (
  port: RuntimeInfoPort,
): RuntimeInfoViewState => {
  const [state, setState] = useState<RuntimeInfoViewState>({
    status: "loading",
  });

  useEffect(() => {
    let active = true;

    void port.read().then((result) => {
      if (!active) {
        return;
      }

      setState(
        result.ok
          ? { status: "ready", info: result.value }
          : { status: "failed", error: result.error },
      );
    });

    return () => {
      active = false;
    };
  }, [port]);

  return state;
};
