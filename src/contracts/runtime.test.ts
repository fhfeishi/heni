import { describe, expect, it } from "vitest";

import { runtimeInfoSchema } from "./runtime";

describe("runtimeInfoSchema", () => {
  it("accepts the camel-case Rust contract", () => {
    const result = runtimeInfoSchema.safeParse({
      appName: "Heni",
      appVersion: "0.1.0",
      platform: "windows",
    });

    expect(result.success).toBe(true);
  });

  it("rejects an unknown platform instead of trusting IPC", () => {
    const result = runtimeInfoSchema.safeParse({
      appName: "Heni",
      appVersion: "0.1.0",
      platform: "webview",
    });

    expect(result.success).toBe(false);
  });
});

