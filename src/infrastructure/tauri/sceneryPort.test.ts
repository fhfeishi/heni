import { describe, expect, it, vi } from "vitest";

import { emptyScenery, type ScenerySnapshot } from "../../contracts/scenery";
import { createSceneryPort } from "./sceneryPort";

const ready: ScenerySnapshot = {
  state: "ready",
  fileName: "海岸.png",
  dataUrl: "data:image/png;base64,AQID",
};

describe("scenery port", () => {
  it("uses argument-free native commands without accepting arbitrary paths", async () => {
    const invoke = vi
      .fn()
      .mockResolvedValueOnce(ready)
      .mockResolvedValueOnce(ready)
      .mockResolvedValueOnce(emptyScenery);
    const port = createSceneryPort(invoke);
    expect(await port.read()).toEqual({ ok: true, value: ready });
    expect(await port.choose()).toEqual({ ok: true, value: ready });
    expect(await port.clear()).toEqual({ ok: true, value: emptyScenery });
    expect(invoke.mock.calls).toEqual([
      ["scenery_read"],
      ["scenery_choose"],
      ["scenery_clear"],
    ]);
  });

  it("keeps cancellation distinct from clearing", async () => {
    const port = createSceneryPort(vi.fn().mockResolvedValue(null));
    expect(await port.choose()).toEqual({ ok: true, value: null });
    expect(await port.read()).toEqual({ ok: false, error: "invalid-contract" });
  });

  it("rejects wrong mutation outcomes and remote image payloads", async () => {
    const port = createSceneryPort(vi.fn().mockResolvedValue(ready));
    expect(await port.clear()).toEqual({
      ok: false,
      error: "invalid-contract",
    });
    const emptyPort = createSceneryPort(
      vi.fn().mockResolvedValue(emptyScenery),
    );
    expect(await emptyPort.choose()).toEqual({
      ok: false,
      error: "invalid-contract",
    });
    const invalidPort = createSceneryPort(
      vi
        .fn()
        .mockResolvedValue({
          ...ready,
          dataUrl: "https://example.com/image.png",
        }),
    );
    expect(await invalidPort.read()).toEqual({
      ok: false,
      error: "invalid-contract",
    });
  });

  it("preserves finite errors but never forwards raw transport diagnostics", async () => {
    const invoke = vi
      .fn()
      .mockRejectedValueOnce("image-too-large")
      .mockRejectedValueOnce(new Error("C:/private/path"));
    const port = createSceneryPort(invoke);
    expect(await port.choose()).toEqual({
      ok: false,
      error: "image-too-large",
    });
    expect(await port.read()).toEqual({ ok: false, error: "transport" });
  });
});
