import { useEffect, useRef, useState } from "react";
import type { VideoOutput } from "./videoOutput";
import { tauriVideoOutput } from "../../infrastructure/tauri/videoOutput";

export const VideoStage = ({ visible, title, output = tauriVideoOutput }: {
  visible: boolean; title: string; output?: VideoOutput | null;
}) => {
  const video = useRef<HTMLVideoElement>(null);
  const [error, setError] = useState<string | null>(null);
  useEffect(() => {
    if (video.current === null || output === null) return;
    return output.attach(video.current, setError);
  }, [output]);
  return <section className="video-stage" hidden={!visible} aria-label="视频舞台">
    <div className="video-stage__surface">
      <video ref={video} playsInline preload="metadata" aria-label={title || "当前视频"} disablePictureInPicture />
      {error && <div className="video-stage__error" role="alert">{error}</div>}
    </div>
    <p className="video-stage__caption">{title}</p>
  </section>;
};
