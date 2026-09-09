import { useState, type CSSProperties } from "react";

import type { AppView } from "./appView";
import { sceneryPresentation } from "./sceneryPresentation";

export interface SceneryBackdropProps {
  activeView: AppView;
  imageUrl?: string | null;
  intensity?: number;
  reveal?: number;
  onImageError?: ((imageUrl: string) => void) | undefined;
  onImageLoad?(imageUrl: string): void;
}

export const SceneryBackdrop = ({
  activeView,
  imageUrl = null,
  intensity = 100,
  reveal = 0,
  onImageError,
  onImageLoad,
}: SceneryBackdropProps) => {
  const [failedImageUrl, setFailedImageUrl] = useState<string | null>(null);
  const [loadedImageUrl, setLoadedImageUrl] = useState<string | null>(null);
  const showImage = imageUrl !== null && imageUrl !== failedImageUrl;
  const mode = activeView === "now-playing" ? "playback" : "browse";

  return (
    <div
      className={`app-scenery app-scenery--${mode}`}
      style={{ ...sceneryPresentation(mode === "playback", reveal), "--scenery-intensity": intensity / 100 } as CSSProperties}
      data-image-state={
        imageUrl === null
          ? "fallback"
          : !showImage
            ? "failed"
            : loadedImageUrl === imageUrl
              ? "ready"
              : "loading"
      }
      aria-hidden="true"
    >
      {showImage && (
        <img
          key={imageUrl}
          className="app-scenery__image"
          src={imageUrl}
          alt=""
          draggable={false}
          onLoad={() => { setLoadedImageUrl(imageUrl); onImageLoad?.(imageUrl); }}
          onError={() => {
            setFailedImageUrl(imageUrl);
            onImageError?.(imageUrl);
          }}
        />
      )}
    </div>
  );
};
