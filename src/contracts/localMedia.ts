import type { PlaybackError, PlaybackItem } from "./playback";
import type { Result } from "./result";

export interface LocalMediaPickerPort {
  pickAudioFiles(): Promise<
    Result<ReadonlyArray<PlaybackItem>, PlaybackError>
  >;
}
