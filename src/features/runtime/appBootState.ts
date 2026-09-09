export type AppBootState =
  | Readonly<{ status: "booting" }>
  | Readonly<{ status: "ready" }>
  | Readonly<{
      status: "degraded";
      reason: "browser-preview" | "core-feature-unavailable";
    }>
  | Readonly<{
      status: "blocked";
      reason: "runtime-transport" | "runtime-contract";
    }>;
