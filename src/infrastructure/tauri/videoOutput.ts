import { invoke, isTauri } from "@tauri-apps/api/core";
import { VideoOutput } from "../../features/playback/videoOutput";

export const tauriVideoOutput = isTauri() ? new VideoOutput({
  exchange: (report) => invoke("video_exchange", { report }),
}) : null;
