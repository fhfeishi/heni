import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { VideoStage } from "./VideoStage";
import { VideoOutput } from "./videoOutput";

describe("VideoStage", () => {
  it("retains the same media element across songs/stage navigation", () => {
    const output = new VideoOutput({ exchange: async () => null });
    const detach = vi.fn();
    const attach = vi.spyOn(output, "attach").mockReturnValue(detach);
    const { rerender, unmount } = render(<VideoStage visible title="测试视频" output={output} />);
    const element = screen.getByLabelText("测试视频");
    rerender(<VideoStage visible={false} title="测试视频" output={output} />);
    expect(element).not.toBeVisible();
    expect(attach).toHaveBeenCalledOnce();
    expect(detach).not.toHaveBeenCalled();
    rerender(<VideoStage visible title="测试视频" output={output} />);
    expect(screen.getByLabelText("测试视频")).toBe(element);
    expect(element).toBeVisible();
    unmount();
    expect(detach).toHaveBeenCalledOnce();
  });
});
