import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import { defaultSettingsSnapshot } from "../../contracts/settings";
import { PreferencesControl } from "./PreferencesControl";

describe("PreferencesControl", () => {
  it("keeps dismissal outside the scroll body and preserves appearance drafts when reopened", () => {
    const update = vi.fn();
    const { container } = render(
      <PreferencesControl settings={defaultSettingsSnapshot} busy={false} onUpdate={update}
        appearanceControls={<input aria-label="外观草稿" defaultValue="35" />} />,
    );
    const details = container.querySelector("details");
    const body = container.querySelector(".preferences-control__body");
    if (details === null || body === null) throw new Error("Settings structure missing");
    details.open = true;
    const draft = screen.getByRole("textbox", { name: "外观草稿" });
    fireEvent.change(draft, { target: { value: "70" } });
    fireEvent.click(screen.getByRole("button", { name: "导入" }));
    expect(screen.queryByRole("textbox", { name: "外观草稿" })).toBeNull();
    fireEvent.click(screen.getByRole("button", { name: "外观" }));
    expect(screen.getByRole("textbox", { name: "外观草稿" })).toBe(draft);
    const close = screen.getByRole("button", { name: "关闭设置" });
    expect(body).toContainElement(draft);
    expect(body).not.toContainElement(close);
    fireEvent.click(close);
    expect(details.open).toBe(false);
    expect(details.querySelector("summary")).toHaveFocus();
    details.open = true;
    expect(screen.getByRole("textbox", { name: "外观草稿" })).toHaveValue("70");
    expect(update).not.toHaveBeenCalled();
  });
  it("offers six coordinated palettes and returns focus when dismissed with Escape", () => {
    const update = vi.fn();
    const { container } = render(<PreferencesControl settings={defaultSettingsSnapshot} busy={false} onUpdate={update} />);
    expect(screen.getAllByRole("button", { name: /^使用.+主题$/u })).toHaveLength(6);
    fireEvent.click(screen.getByRole("button", { name: "使用鸢尾主题" }));
    expect(update).toHaveBeenCalledWith({ themeId: "iris" });
    const details = container.querySelector("details");
    if (details === null) throw new Error("Settings root missing");
    details.open = true;
    fireEvent.keyDown(screen.getByRole("button", { name: "关闭设置" }), { key: "Escape" });
    expect(details.open).toBe(false);
    expect(details.querySelector("summary")).toHaveFocus();
    details.open = true;
    fireEvent.pointerDown(document.body);
    expect(details.open).toBe(false);
  });
  it("emits one typed partial update per preference", () => {
    const update = vi.fn();
    render(
      <PreferencesControl
        settings={defaultSettingsSnapshot}
        busy={false}
        onUpdate={update}
      />,
    );

    fireEvent.click(screen.getByRole("button", { name: "导入" }));
    fireEvent.click(screen.getByLabelText("扫描视频文件"));
    fireEvent.click(screen.getByLabelText("扫描子文件夹"));

    expect(update).toHaveBeenNthCalledWith(1, { includeVideo: false });
    expect(update).toHaveBeenNthCalledWith(2, { recursiveScan: false });
    expect(screen.queryByLabelText("导入后自动播放")).toBeNull();
    expect(screen.getByText(/导入只收录媒体/u)).toBeInTheDocument();
  });

  it("disables every preference while persistence is busy", () => {
    render(
      <PreferencesControl
        settings={defaultSettingsSnapshot}
        busy={true}
        onUpdate={vi.fn()}
      />,
    );

    fireEvent.click(screen.getByRole("button", { name: "导入" }));
    expect(screen.getByRole("group", { name: "扫描与导入" })).toBeDisabled();
  });

  it("keeps a settings failure local to the preferences control", () => {
    render(
      <PreferencesControl
        settings={defaultSettingsSnapshot}
        busy={false}
        errorMessage="设置暂未保存，其他功能不受影响。"
        onUpdate={vi.fn()}
      />,
    );

    expect(screen.getByRole("status")).toHaveTextContent("设置暂未保存");
    fireEvent.click(screen.getByRole("button", { name: "导入" }));
    expect(screen.getByRole("group", { name: "扫描与导入" })).not.toBeDisabled();
    expect(screen.getByRole("status")).toHaveTextContent("设置暂未保存");
    expect(
      screen.getByLabelText("打开扫描与导入设置，设置未保存"),
    ).toBeInTheDocument();
    expect(
      screen.getByText("设置暂未保存，其他功能不受影响。"),
    ).toBeInTheDocument();
  });
});
