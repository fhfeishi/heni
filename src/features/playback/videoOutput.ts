import { z } from "zod";
import type { PlaybackCommand } from "../../contracts/playback";

export const videoIntentSchema = z.object({
  source: z.string().regex(/^http:\/\/127\.0\.0\.1:\d+\/[a-f0-9]{32}\/\d+$/u),
  epoch: z.number().int().nonnegative(), revision: z.number().int().nonnegative(),
  positionMs: z.number().int().nonnegative(), playing: z.boolean(),
  volume: z.number().min(0).max(100), muted: z.boolean(),
}).nullable();
type VideoIntent = NonNullable<z.infer<typeof videoIntentSchema>>;
export interface VideoReport {
  epoch: number; revision: number; positionMs: number; durationMs: number | null;
  paused: boolean; ended: boolean; failed: boolean;
}
export interface VideoBridgePort {
  exchange(report: VideoReport | null): Promise<unknown>;
}

/** Owns exactly one media element. Navigation only changes its visibility. */
export class VideoOutput {
  private element: HTMLVideoElement | null = null;
  private intent: VideoIntent | null = null;
  private revision = 0;
  private suspended = 0;
  private failed = false;
  private seekPending = false;
  private notify: (error: string | null) => void = () => undefined;

  constructor(private readonly port: VideoBridgePort) {}

  attach(element: HTMLVideoElement, notify: (error: string | null) => void): () => void {
    if (this.element !== null) throw new Error("Only one video surface may be attached.");
    this.element = element;
    this.notify = notify;
    let active = true;
    let timer: ReturnType<typeof setTimeout>;
    const poll = async () => {
      const revision = this.revision;
      try {
        const value = videoIntentSchema.parse(await this.port.exchange(this.report()));
        if (active && revision === this.revision && this.suspended === 0) this.apply(value);
      } catch {
        if (active && revision === this.revision) {
          element.pause();
          notify("视频连接暂时中断，请重试播放。");
        }
      } finally {
        if (active) timer = setTimeout(() => void poll(), this.intent === null ? 350 : 100);
      }
    };
    const ready = () => this.synchronize();
    const error = () => this.fail("无法播放这个视频的编码，或文件已损坏。请尝试 H.264/AAC MP4 或 WebM。");
    element.addEventListener("loadedmetadata", ready);
    element.addEventListener("error", error);
    void poll();
    return () => {
      active = false;
      clearTimeout(timer);
      this.revision++;
      element.removeEventListener("loadedmetadata", ready);
      element.removeEventListener("error", error);
      this.release();
      this.element = null;
      this.notify = () => undefined;
    };
  }

  async withCommand<T>(command: PlaybackCommand, dispatch: () => Promise<T>): Promise<T> {
    const transfersOutput = ["replace-queue", "play", "pause", "stop", "seek", "next", "previous", "play-index", "remove-index", "refresh-item"].includes(command.type);
    if (!transfersOutput || this.element === null) return dispatch();
    this.suspended++;
    this.revision++;
    this.element.pause();
    try {
      // Acknowledge quiet output before Rust may start native audio.
      const report = this.report();
      const current = videoIntentSchema.parse(await this.port.exchange(report));
      // A gain/pause update can change the intent revision between UI input and acknowledgment.
      if (current !== null && report !== null && current.epoch === report.epoch && current.revision !== report.revision) {
        await this.port.exchange({ ...report, revision: current.revision, paused: true });
      }
      return await dispatch();
    } finally {
      this.suspended--;
      this.revision++;
    }
  }

  private report(): VideoReport | null {
    const element = this.element;
    const intent = this.intent;
    if (element === null || intent === null) return null;
    return {
      epoch: intent.epoch, revision: intent.revision,
      positionMs: this.seekPending ? intent.positionMs : Math.max(0, Math.round(element.currentTime * 1000)),
      durationMs: Number.isFinite(element.duration) ? Math.max(0, Math.round(element.duration * 1000)) : null,
      paused: element.paused, ended: element.ended, failed: this.failed,
    };
  }

  private release(): void {
    if (this.element === null) return;
    this.element.pause();
    this.element.removeAttribute("src");
    this.element.load();
    this.intent = null;
    this.failed = false;
  }

  private apply(intent: VideoIntent | null): void {
    const element = this.element;
    if (element === null) return;
    if (intent === null) {
      if (this.intent !== null) this.release();
      return;
    }
    if (this.intent !== null && (intent.epoch < this.intent.epoch || (intent.epoch === this.intent.epoch && intent.revision < this.intent.revision))) return;
    const changedSource = intent.epoch !== this.intent?.epoch;
    this.intent = intent;
    if (changedSource) {
      element.pause();
      this.failed = false;
      this.seekPending = true;
      this.notify(null);
      element.src = intent.source;
      element.load();
    }
    this.synchronize();
  }

  private synchronize(): void {
    const element = this.element;
    const intent = this.intent;
    if (element === null || intent === null || this.suspended > 0 || this.failed) return;
    element.volume = intent.volume / 100;
    element.muted = intent.muted;
    if (element.readyState === 0) return;
    if (this.seekPending) {
      element.currentTime = intent.positionMs / 1000;
      this.seekPending = false;
    }
    if (!intent.playing) { element.pause(); return; }
    if (element.paused && !element.ended) {
      const revision = this.revision;
      void element.play().catch((cause: unknown) => {
        if (this.intent?.epoch !== intent.epoch || revision !== this.revision || this.suspended > 0) return;
        if (cause instanceof DOMException && cause.name === "AbortError") return;
        this.fail("视频未能开始播放，请重试；若持续失败，请检查文件编码。");
      });
    }
  }

  private fail(message: string): void {
    this.failed = true;
    this.element?.pause();
    this.notify(message);
  }
}
