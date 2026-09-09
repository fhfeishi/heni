import type { AppView } from "./appView";

export const NavigationIcon = ({ view }: { view: AppView }) => {
  if (view === "now-playing") {
    return (
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <circle cx="12" cy="12" r="8" />
        <circle cx="12" cy="12" r="2.5" />
      </svg>
    );
  }
  if (view === "library") {
    return (
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M5 5.5h14v13H5z" />
        <path d="M8.5 9h7M8.5 12h7M8.5 15h4" />
      </svg>
    );
  }
  if (view === "playlists") {
    return (
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M5 7h9M5 11h9M5 15h6" />
        <path d="M17 10v7.2a2.2 2.2 0 1 1-1.5-2.1V11z" />
      </svg>
    );
  }
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path d="M7 6h12M7 12h12M7 18h12" />
      <circle cx="4" cy="6" r="1" />
      <circle cx="4" cy="12" r="1" />
      <circle cx="4" cy="18" r="1" />
    </svg>
  );
};
