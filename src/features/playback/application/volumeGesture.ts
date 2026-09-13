import type { PlaybackCommand, PlaybackSnapshot } from "../../../contracts/playback";

type Dispatch = (command: PlaybackCommand) => Promise<boolean>;

/** One gesture, one in-flight request, one latest target. Nothing here owns saved volume. */
export class VolumeGesture {
  readonly generation: number;
  readonly sequence: number;
  readonly gestureId = crypto.randomUUID();
  volume: number;
  closing = false;
  private timer: ReturnType<typeof setTimeout> | undefined;
  private inFlight: Promise<boolean> | null = null;
  private sentVolume: number | null = null;
  private lastPreviewAt = 0;
  private failed = false;
  private completion: Promise<boolean> | null = null;

  constructor(snapshot: PlaybackSnapshot, private readonly dispatch: Dispatch, private readonly onFailure: () => void) {
    this.generation = snapshot.generation;
    this.sequence = snapshot.sequence;
    this.volume = snapshot.volume;
  }

  private get identity() {
    return { generation: this.generation, sequence: this.sequence, gestureId: this.gestureId };
  }

  stage(volume: number): void {
    if (this.closing) return;
    this.volume = volume;
    if (this.inFlight === null) this.schedule(Math.max(0, 40 - (performance.now() - this.lastPreviewAt)));
  }

  private schedule(delay: number): void {
    clearTimeout(this.timer);
    this.timer = setTimeout(() => void this.preview(), delay);
  }

  private async send(command: PlaybackCommand): Promise<boolean> {
    try { return await this.dispatch(command); } catch { return false; }
  }

  private preview(): Promise<boolean> {
    if (this.inFlight !== null) return this.inFlight;
    this.lastPreviewAt = performance.now();
    const volume = this.volume;
    this.sentVolume = volume;
    const request = this.send({ type: "preview-volume", volume, ...this.identity });
    this.inFlight = request;
    void request.then((ok) => {
      this.inFlight = null;
      this.failed ||= !ok;
      if (this.closing) return;
      if (!ok) {
        void this.finish(false).then(this.onFailure);
      } else {
        // Renew while a held pointer/key is still, so the native two-second lease stays alive.
        this.schedule(this.volume === volume ? 500 : 40);
      }
    });
    return request;
  }

  finish(commit: boolean): Promise<boolean> {
    if (this.completion !== null) return this.completion;
    this.closing = true;
    clearTimeout(this.timer);
    this.completion = this.complete(commit);
    return this.completion;
  }

  private async complete(commit: boolean): Promise<boolean> {
    if (this.inFlight !== null) this.failed ||= !(await this.inFlight);
    if (commit && !this.failed) {
      // Even a quick click needs an accepted preview to establish ownership before committing.
      if (this.sentVolume !== this.volume) this.failed ||= !(await this.preview());
      if (!this.failed && await this.send({ type: "commit-volume-preview", volume: this.volume, ...this.identity })) return true;
    }
    await this.send({ type: "cancel-volume-preview", ...this.identity });
    return !commit && !this.failed;
  }
}
