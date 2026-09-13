import { act, renderHook, waitFor } from "@testing-library/react";
import { expect, it, vi } from "vitest";
import type { WindowPort, WindowSnapshot } from "../../contracts/window";
import { useWindowMode } from "./useWindowMode";

it("renders mini before resize completes and rolls back a rejected resize", async () => {
  const main: WindowSnapshot = { mode: "main", maximized: false, alwaysOnTop: false, innerWidth: 1000, innerHeight: 700, scaleFactor: 1 };
  let finish!: (result: Awaited<ReturnType<WindowPort["setMode"]>>) => void;
  const port: WindowPort = {
    read: vi.fn(async () => ({ ok: true as const, value: main })),
    setMode: vi.fn(() => new Promise<Awaited<ReturnType<WindowPort["setMode"]>>>((resolve) => { finish = resolve; })),
  };
  const { result } = renderHook(() => useWindowMode(port));
  await waitFor(() => expect(result.current.available).toBe(true));
  let transition!: Promise<boolean>;
  act(() => { transition = result.current.setMode("mini-player"); });
  expect(result.current.mode).toBe("mini-player");
  expect(result.current.busy).toBe(true);
  await act(async () => {
    finish({ ok: false, error: { code: "window-unavailable", message: "resize failed" } });
    await transition;
  });
  expect(result.current.mode).toBe("main");
  expect(result.current.busy).toBe(false);
  expect(result.current.error?.code).toBe("window-unavailable");
});
