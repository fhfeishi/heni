import { fireEvent, render, screen, within } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { AppFrame, type AppFrameProps } from "./AppFrame";
import { ListeningViewSwitch } from "./ListeningViewSwitch";

const frameProps: AppFrameProps = {
  activeView: "now-playing", bootState: { status: "ready" },
  libraryCount: 0, playlistCount: 0, queueCount: 0, themeId: "studio",
  windowMode: "main", windowControlsAvailable: true, windowBusy: false,
  onSelectView: vi.fn(), onSelectTheme: vi.fn(), onToggleWindowMode: vi.fn(),
  children: <p>舞台内容</p>, playbackBar: null, miniPlayer: null,
};

describe("AppFrame toolbar", () => {
  it("keeps edge panels out of mini mode and restores the main surface", () => {
    const { rerender } = render(<AppFrame {...frameProps} playbackBar={<button>底部播放</button>} miniPlayer={<p>紧凑播放</p>} />);
    expect(screen.getByRole("button", { name: "展开播放控制" })).toBeInTheDocument();
    rerender(<AppFrame {...frameProps} windowMode="mini-player" playbackBar={<button>底部播放</button>} miniPlayer={<p>紧凑播放</p>} />);
    expect(screen.queryByRole("button", { name: "展开播放控制" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "底部播放" })).not.toBeInTheDocument();
    expect(screen.getByText("紧凑播放")).toBeInTheDocument();
    rerender(<AppFrame {...frameProps} />);
    expect(screen.getByRole("button", { name: "展开顶部工具" })).toBeInTheDocument();
  });
  it("uses one central surface for audio/video and restores the browsing presentation", () => {
    const { container, rerender } = render(<AppFrame {...frameProps} />);
    const main = screen.getByRole("main");
    expect(container.querySelectorAll(".app-glass")).toHaveLength(1);
    expect(main).not.toContainElement(container.querySelector(".app-glass"));
    expect(container.querySelector(".app-frame")).toHaveAttribute("data-stage", "true");
    expect(main).toHaveAttribute("data-presentation", "audio");
    rerender(<AppFrame {...frameProps} videoVisible />);
    expect(main).toHaveAttribute("data-presentation", "video");
    rerender(<AppFrame {...frameProps} activeView="library" />);
    expect(main).toHaveAttribute("data-presentation", "browse");
    expect(container.querySelector(".app-frame")).toHaveAttribute("data-stage", "false");
  });

  it("conceals only central content after image load and restores interaction from the toolbar", () => {
    const { container } = render(<AppFrame {...frameProps} sceneryImageUrl="blob:picture" sceneryReveal={300}
      playbackBar={<button>播放控制</button>}><button>中央操作</button></AppFrame>);
    const main = screen.getByRole("main");
    expect(main).not.toHaveAttribute("inert");
    const picture = container.querySelector(".app-scenery__image");
    if (picture === null) throw new Error("Missing picture");
    screen.getByRole("button", { name: "中央操作" }).focus();
    fireEvent.load(picture);
    expect(screen.getByRole("button", { name: "显示内容" })).toHaveFocus();
    expect(main).toHaveAttribute("inert");
    expect(main).toHaveStyle({ opacity: "0" });
    expect(container.querySelector(".app-glass")).toHaveStyle({ opacity: "0" });
    expect(screen.getByRole("button", { name: "播放控制" })).not.toHaveAttribute("inert");
    fireEvent.click(screen.getByRole("button", { name: "显示内容" }));
    expect(main).not.toHaveAttribute("inert");
    expect(main).toHaveStyle({ opacity: "1" });
    expect(container.querySelector(".app-glass")).toHaveStyle({ opacity: "1" });
    fireEvent.click(screen.getByRole("button", { name: "恢复背景沉浸" }));
    fireEvent.error(picture);
    expect(main).not.toHaveAttribute("inert");
    expect(main).toHaveStyle({ opacity: "1" });
  });

  it("excludes video, zero intensity and old values from content concealment", () => {
    const { container, rerender } = render(<AppFrame {...frameProps} sceneryImageUrl="blob:picture" sceneryReveal={300} videoVisible />);
    const picture = container.querySelector(".app-scenery__image");
    if (picture === null) throw new Error("Missing picture");
    fireEvent.load(picture);
    expect(screen.getByRole("main")).not.toHaveAttribute("inert");
    rerender(<AppFrame {...frameProps} sceneryImageUrl="blob:picture" sceneryReveal={300} sceneryIntensity={0} />);
    expect(screen.getByRole("main")).not.toHaveAttribute("inert");
    rerender(<AppFrame {...frameProps} sceneryImageUrl="blob:picture" sceneryReveal={100} />);
    expect(screen.getByRole("main")).not.toHaveAttribute("inert");
  });
  it("hosts the only view switch in the top glass and delegates background selection", () => {
    const choose = vi.fn();
    const browse = vi.fn();
    const { container } = render(<AppFrame {...frameProps} onChooseScenery={choose}
      viewControls={<ListeningViewSwitch stage onBrowse={browse} onStage={vi.fn()} />} />);
    const toolbar = container.querySelector(".app-topbar");
    if (!(toolbar instanceof HTMLElement)) throw new Error("Missing top glass");
    expect(screen.getAllByRole("group", { name: "聆听视图" })).toHaveLength(1);
    expect(toolbar).toContainElement(screen.getByRole("group", { name: "聆听视图" }));
    fireEvent.click(within(toolbar).getByRole("button", { name: "歌曲" }));
    fireEvent.click(within(toolbar).getByRole("button", { name: "更换背景图片" }));
    expect(browse).toHaveBeenCalledOnce();
    expect(choose).toHaveBeenCalledOnce();
    expect(screen.getByRole("main")).not.toContainElement(screen.getByRole("group", { name: "聆听视图" }));
  });

  it("does not open the picker while busy or in browser preview", () => {
    const choose = vi.fn();
    const { rerender } = render(<AppFrame {...frameProps} onChooseScenery={choose} sceneryBusy />);
    fireEvent.click(screen.getByRole("button", { name: "更换背景图片" }));
    rerender(<AppFrame {...frameProps} onChooseScenery={choose} sceneryAvailable={false} />);
    expect(screen.getByRole("button", { name: "更换背景图片" })).toBeDisabled();
    fireEvent.click(screen.getByRole("button", { name: "更换背景图片" }));
    expect(choose).not.toHaveBeenCalled();
  });
});
