import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { ListeningViewSwitch } from "./ListeningViewSwitch";

describe("ListeningViewSwitch", () => {
  it("keeps explicit names and delegates view changes without internal navigation state", () => {
    const browse = vi.fn();
    const stage = vi.fn();
    render(<ListeningViewSwitch stage onBrowse={browse} onStage={stage} />);
    expect(screen.getByRole("button", { name: "播放舞台" })).toHaveAttribute("aria-pressed", "true");
    fireEvent.click(screen.getByRole("button", { name: "歌曲" }));
    expect(browse).toHaveBeenCalledOnce();
    expect(stage).not.toHaveBeenCalled();
  });
  it("supports arrow keys and Home/End while keeping focus visible on the target", () => {
    const browse = vi.fn();
    const stage = vi.fn();
    render(<ListeningViewSwitch stage={false} onBrowse={browse} onStage={stage} />);
    const songs = screen.getByRole("button", { name: "歌曲" });
    const theatre = screen.getByRole("button", { name: "播放舞台" });
    fireEvent.keyDown(songs, { key: "ArrowRight" });
    expect(theatre).toHaveFocus();
    expect(stage).toHaveBeenCalledOnce();
    fireEvent.keyDown(theatre, { key: "Home" });
    expect(songs).toHaveFocus();
    expect(browse).toHaveBeenCalledOnce();
    fireEvent.keyDown(songs, { key: "ArrowRight", ctrlKey: true });
    expect(stage).toHaveBeenCalledOnce();
  });
});
