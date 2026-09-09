import { useEffect } from "react";

export const SCENERY_ROTATION_MS = 11_000;

/** One pending timeout, no catch-up burst after returning to the window. */
export const useSceneryRotation = (enabled: boolean, next: () => Promise<boolean>) => {
  useEffect(() => {
    if (!enabled) return;
    const motion = window.matchMedia?.("(prefers-reduced-motion: reduce)");
    let timer: ReturnType<typeof setTimeout> | undefined;
    let active = true;
    let focused = document.hasFocus();
    const clear = () => {
      if (timer !== undefined) clearTimeout(timer);
      timer = undefined;
    };
    const schedule = () => {
      clear();
      if (!active || document.hidden || !focused || motion?.matches) return;
      timer = setTimeout(() => {
        timer = undefined;
        // Recheck at execution time, not only when the timer was scheduled.
        if (!active || document.hidden || !focused || motion?.matches) return;
        void next().then((success) => { if (success) schedule(); });
      }, SCENERY_ROTATION_MS);
    };
    const onFocus = () => { focused = true; schedule(); };
    const onBlur = () => { focused = false; clear(); };
    window.addEventListener("focus", onFocus);
    window.addEventListener("blur", onBlur);
    document.addEventListener("visibilitychange", schedule);
    motion?.addEventListener("change", schedule);
    schedule();
    return () => {
      active = false;
      clear();
      window.removeEventListener("focus", onFocus);
      window.removeEventListener("blur", onBlur);
      document.removeEventListener("visibilitychange", schedule);
      motion?.removeEventListener("change", schedule);
    };
  }, [enabled, next]);
};
