import type { CSSProperties } from "react";
import type { GlassSettings } from "../../contracts/settings";

const blur = { clear: 4, soft: 16, frosted: 28 } as const;

/** Keep a local text backing even at the clearest end; never fade the entire UI. */
export const glassStyle = (value: GlassSettings): CSSProperties => ({
  "--glass-fill": `${94 - value.transparency * 0.54}%`,
  "--glass-blur": `${blur[value.material]}px`,
} as CSSProperties);
