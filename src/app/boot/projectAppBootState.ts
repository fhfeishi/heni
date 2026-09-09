import type { RuntimeInfoViewState } from "../../features/runtime/useRuntimeInfo";
import type { AppBootState } from "../../features/runtime/appBootState";

export interface AppBootProjectionInput {
  runtime: RuntimeInfoViewState;
  playback: Readonly<{ loading: boolean; available: boolean }>;
  library: Readonly<{ loading: boolean; available: boolean }>;
}

export const projectAppBootState = ({
  runtime,
  playback,
  library,
}: AppBootProjectionInput): AppBootState => {
  if (runtime.status === "loading") {
    return { status: "booting" };
  }
  if (runtime.status === "failed") {
    if (runtime.error.code === "browser-preview") {
      return { status: "degraded", reason: "browser-preview" };
    }
    return {
      status: "blocked",
      reason:
        runtime.error.code === "invalid-contract"
          ? "runtime-contract"
          : "runtime-transport",
    };
  }
  if (playback.loading || library.loading) {
    return { status: "booting" };
  }
  if (!playback.available || !library.available) {
    return { status: "degraded", reason: "core-feature-unavailable" };
  }
  return { status: "ready" };
};
