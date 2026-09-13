import type { CSSProperties } from "react";
import { glassFog, type GlassSettings } from "../../contracts/settings";

/** Keep a local text backing even at the clearest end; never fade the entire UI. */
export const glassStyle = (value: GlassSettings): CSSProperties => ({
  "--glass-fill": `${94 - value.transparency * 0.54}%`,
  "--glass-blur": `${glassFog(value) * 0.4}px`,
} as CSSProperties);
