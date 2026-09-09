import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { DraftActions } from "./DraftActions";

describe("DraftActions", () => {
  it("keeps precise names and callbacks without visible text glyphs", () => {
    const save = vi.fn();
    const cancel = vi.fn();
    const reset = vi.fn();
    render(<DraftActions dirty saveLabel="保存材质" cancelLabel="取消预览" onSave={save} onCancel={cancel}
      reset={{ label: "恢复默认材质", onClick: reset }} />);
    for (const label of ["保存材质", "取消预览", "恢复默认材质"]) {
      const button = screen.getByRole("button", { name: label });
      expect(button).toHaveAttribute("title", label);
      expect(button.textContent).toBe("");
      expect(button.querySelector("svg")).toHaveAttribute("aria-hidden", "true");
      fireEvent.click(button);
    }
    expect(save).toHaveBeenCalledOnce();
    expect(cancel).toHaveBeenCalledOnce();
    expect(reset).toHaveBeenCalledOnce();
  });
  it("disables clean actions and respects the reset boundary", () => {
    const save = vi.fn();
    render(<DraftActions dirty={false} saveLabel="保存" cancelLabel="取消" onSave={save} onCancel={vi.fn()}
      reset={{ label: "恢复", disabled: true, onClick: vi.fn() }} />);
    for (const button of screen.getAllByRole("button")) expect(button).toBeDisabled();
    fireEvent.click(screen.getByRole("button", { name: "保存" }));
    expect(save).not.toHaveBeenCalled();
  });
});
