import type { CSSProperties } from "react";

export const sceneryImmersion = (reveal: number): number =>
  Number.isFinite(reveal) ? Math.min(1, Math.max(0, (reveal - 100) / 200)) : 0;

/** Zero preserves the legacy picture treatment. Browse views retain a reading scrim. */
export const sceneryPresentation = (playback: boolean, reveal: number): CSSProperties => {
  const amount = Number.isFinite(reveal) ? Math.min(100, Math.max(0, reveal)) / 100 : 0;
  const mix = (start: number, end: number) => start + (end - start) * amount;
  const immersion = sceneryImmersion(reveal);
  const settle = (value: number, target: number) => value + (target - value) * immersion;
  return {
    "--scenery-image-opacity": settle(mix(playback ? 0.72 : 0.42, playback ? 1 : 0.65), 1),
    "--scenery-image-shade": `${settle(mix(playback ? 52 : 64, playback ? 0 : 45), 0)}%`,
    "--scenery-bottom-shade": `${settle(mix(playback ? 18 : 28, playback ? 0 : 20), 0)}%`,
    "--scenery-top-shade": `${settle(mix(7, playback ? 0 : 7), 0)}%`,
    "--scenery-tint": `${settle(mix(5, playback ? 0 : 5), 0)}%`,
    "--scenery-blur": `${settle(mix(playback ? 2 : 5, playback ? 0 : 3), 0)}px`,
    "--scenery-saturation": settle(mix(playback ? 0.92 : 0.72, playback ? 1 : 0.85), 1),
  } as CSSProperties;
};
