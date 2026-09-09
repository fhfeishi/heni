import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import { ThemeControl } from "./ThemeControl";

describe("ThemeControl", () => {
  it("narrows the selected value before notifying the app shell", () => {
    const select = vi.fn();
    render(<ThemeControl themeId="studio" onSelect={select} />);

    fireEvent.change(screen.getByRole("combobox", { name: "界面主题" }), {
      target: { value: "tide" },
    });

    expect(select).toHaveBeenCalledWith("tide");
  });
});
