import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import { emptyScenery } from "../../contracts/scenery";
import { SceneryControl } from "./SceneryControl";

const defaults = {
  snapshot: emptyScenery,
  loading: false,
  busy: false,
  error: null,
  preview: false,
  onChoose: vi.fn(),
  onClear: vi.fn(),
};

describe("SceneryControl", () => {
  it("allows stepping past a missing image and disables switching while saving", () => {
    const next = vi.fn();
    const props = { ...defaults, snapshot: { state: "unavailable" as const, fileName: "missing.png", reason: "file-unavailable" as const, collection: { index: 1, count: 3 } }, canStep: true, onNext: next };
    const { rerender } = render(<SceneryControl {...props} />);
    expect(screen.getByText("2 / 3")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "下一张背景" }));
    expect(next).toHaveBeenCalledOnce();
    rerender(<SceneryControl {...props} busy />);
    expect(screen.getByRole("button", { name: "下一张背景" })).toBeDisabled();
  });
  it("offers local selection while an empty background cannot be cleared", () => {
    const choose = vi.fn();
    render(<SceneryControl {...defaults} onChoose={choose} />);
    fireEvent.click(screen.getByRole("button", { name: "选择图片" }));
    expect(choose).toHaveBeenCalledOnce();
    expect(screen.getByRole("button", { name: "清除背景" })).toBeDisabled();
  });

  it("keeps a missing selection visible and recoverable without exposing its path", () => {
    const clear = vi.fn();
    render(
      <SceneryControl
        {...defaults}
        snapshot={{
          state: "unavailable",
          fileName: "海岸.png",
          reason: "file-unavailable",
        }}
        onClear={clear}
      />,
    );
    expect(screen.getByText("海岸.png")).toBeInTheDocument();
    expect(screen.getByRole("status")).toHaveTextContent("图片已移动");
    fireEvent.click(screen.getByRole("button", { name: "清除背景" }));
    expect(clear).toHaveBeenCalledOnce();
  });

  it("uses preview copy instead of presenting an expected transport failure", () => {
    render(<SceneryControl {...defaults} preview error="transport" />);
    expect(screen.getByRole("group", { name: "美景背景" })).toBeDisabled();
    expect(screen.getByText("请在桌面版中选择本地图片。")).toBeInTheDocument();
    expect(screen.queryByRole("status")).toBeNull();
  });

  it("disables selection and clearing while loading or saving", () => {
    const { rerender } = render(<SceneryControl {...defaults} loading />);
    expect(screen.getByRole("group", { name: "美景背景" })).toBeDisabled();
    rerender(<SceneryControl {...defaults} busy />);
    expect(screen.getByRole("group", { name: "美景背景" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "处理中…" })).toBeDisabled();
  });
});
