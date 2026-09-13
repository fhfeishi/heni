import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { VideoOutput, type VideoReport } from "./videoOutput";

const intent = (epoch = 1) => ({ source: `http://127.0.0.1:43210/${"a".repeat(32)}/${epoch}`, epoch, revision: 0, positionMs: 4000, playing: true, volume: 25, muted: false });
const flush = async () => { await Promise.resolve(); await Promise.resolve(); await Promise.resolve(); };

describe("VideoOutput", () => {
  let video: HTMLVideoElement;
  beforeEach(() => {
    vi.useFakeTimers();
    video = document.createElement("video");
    Object.defineProperties(video, {
      readyState: { value: 1, configurable: true },
      paused: { value: true, configurable: true },
      duration: { value: 12, configurable: true },
    });
    vi.spyOn(video, "load").mockImplementation(() => undefined);
    vi.spyOn(video, "pause").mockImplementation(() => { Object.defineProperty(video, "paused", { value: true }); });
    vi.spyOn(video, "play").mockImplementation(async () => { Object.defineProperty(video, "paused", { value: false }); });
  });
  afterEach(() => { vi.useRealTimers(); vi.restoreAllMocks(); });

  it("uses one scoped source, applies position and gain, and releases on detach", async () => {
    const exchange = vi.fn().mockResolvedValue(intent());
    const output = new VideoOutput({ exchange });
    const detach = output.attach(video, vi.fn());
    await flush();
    expect(video.src).toBe(intent().source);
    expect(video.currentTime).toBe(4);
    expect(video.volume).toBe(0.25);
    expect(video.play).toHaveBeenCalledOnce();
    await vi.advanceTimersByTimeAsync(100);
    expect(exchange).toHaveBeenLastCalledWith(expect.objectContaining({ epoch: 1, positionMs: 4000, durationMs: 12000, paused: false }));
    expect(video.load).toHaveBeenCalledOnce();
    detach();
    expect(video.hasAttribute("src")).toBe(false);
    expect(video.paused).toBe(true);
    expect(vi.getTimerCount()).toBe(0);
  });

  it("acknowledges quiet output before a queue command can start native audio", async () => {
    const events: string[] = [];
    let next: ReturnType<typeof intent> | null = intent();
    const exchange = vi.fn(async (report: VideoReport | null) => {
      if (report?.paused) events.push("quiet");
      return next;
    });
    const output = new VideoOutput({ exchange });
    const detach = output.attach(video, vi.fn());
    await flush();
    await output.withCommand({ type: "next" }, async () => { events.push("dispatch"); next = null; });
    expect(events).toEqual(["quiet", "dispatch"]);
    expect(video.paused).toBe(true);
    await vi.advanceTimersByTimeAsync(100);
    expect(video.hasAttribute("src")).toBe(false);
    detach();
  });

  it("does not interrupt video when only volume or mode is changed", async () => {
    const output = new VideoOutput({ exchange: async () => intent() });
    const detach = output.attach(video, vi.fn());
    await flush();
    vi.mocked(video.pause).mockClear();
    await output.withCommand({ type: "set-volume", volume: 60 }, async () => undefined);
    expect(video.pause).not.toHaveBeenCalled();
    detach();
  });

  it("refreshes a stale revision before acknowledging a paused output", async () => {
    let current = intent();
    const exchange = vi.fn(async () => current);
    const output = new VideoOutput({ exchange });
    const detach = output.attach(video, vi.fn());
    await flush();
    current = { ...current, revision: 2, volume: 60 };
    const dispatch = vi.fn(async () => undefined);
    await output.withCommand({ type: "next" }, dispatch);
    expect(exchange).toHaveBeenLastCalledWith(expect.objectContaining({ epoch: 1, revision: 2, paused: true }));
    expect(dispatch).toHaveBeenCalledOnce();
    detach();
  });

  it("applies audition and committed gain without reloading, seeking or pausing video", async () => {
    let current = intent();
    const output = new VideoOutput({ exchange: async () => current });
    const detach = output.attach(video, vi.fn());
    await flush();
    vi.mocked(video.pause).mockClear();
    vi.mocked(video.load).mockClear();
    video.currentTime = 7;
    for (const type of ["preview-volume", "commit-volume-preview"] as const) {
      await output.withCommand({ type, volume: 60, generation: 1, sequence: 1, gestureId: "owner" }, async () => {
        current = { ...current, revision: current.revision + 1, volume: 60 };
      });
      await vi.advanceTimersByTimeAsync(100);
      expect(video.volume).toBe(0.6);
      expect(video.currentTime).toBe(7);
      expect(video.pause).not.toHaveBeenCalled();
      expect(video.load).not.toHaveBeenCalled();
    }
    detach();
  });

  it("does not dispatch a replacement when the quiet acknowledgment fails", async () => {
    const exchange = vi.fn().mockResolvedValue(intent());
    const output = new VideoOutput({ exchange });
    const detach = output.attach(video, vi.fn());
    await flush();
    exchange.mockRejectedValueOnce(new Error("offline"));
    const dispatch = vi.fn();
    await expect(output.withCommand({ type: "next" }, dispatch)).rejects.toThrow("offline");
    expect(dispatch).not.toHaveBeenCalled();
    expect(video.paused).toBe(true);
    detach();
  });

  it("discards a late source reply after detach", async () => {
    let resolve!: (value: ReturnType<typeof intent>) => void;
    const output = new VideoOutput({ exchange: () => new Promise((done) => { resolve = done; }) });
    const detach = output.attach(video, vi.fn());
    detach();
    resolve(intent());
    await flush();
    expect(video.hasAttribute("src")).toBe(false);
    expect(video.play).not.toHaveBeenCalled();
    expect(vi.getTimerCount()).toBe(0);
  });

  it("reports unsupported video instead of retrying play forever", async () => {
    vi.mocked(video.play).mockRejectedValue(new DOMException("unsupported", "NotSupportedError"));
    const exchange = vi.fn().mockResolvedValue(intent());
    const notify = vi.fn();
    const output = new VideoOutput({ exchange });
    const detach = output.attach(video, notify);
    await flush();
    await vi.advanceTimersByTimeAsync(200);
    expect(notify).toHaveBeenCalledWith(expect.stringContaining("视频未能开始播放"));
    expect(exchange).toHaveBeenLastCalledWith(expect.objectContaining({ failed: true, paused: true }));
    expect(video.play).toHaveBeenCalledOnce();
    detach();
  });

  it("rejects a second media surface to prevent duplicate sound", () => {
    const output = new VideoOutput({ exchange: async () => null });
    const detach = output.attach(video, vi.fn());
    expect(() => output.attach(document.createElement("video"), vi.fn())).toThrow("Only one");
    detach();
  });
});
