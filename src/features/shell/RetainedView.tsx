import { useState, type ReactNode } from "react";

/** Only visited browse panes are retained. Hidden panes contain no active clocks. */
export const RetainedView = ({ active, children }: {
  active: boolean;
  children: ReactNode;
}) => {
  const [visited, setVisited] = useState(active);
  if (active && !visited) setVisited(true);
  return (
    <div className="retained-view" hidden={!active} inert={!active}>
      {active || visited ? children : null}
    </div>
  );
};
