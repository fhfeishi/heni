import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { WindowChrome } from "./WindowChrome";

const createPort = () => ({
  isMaximized: vi.fn().mockResolvedValue(false),
  minimize: vi.fn().mockResolvedValue(undefined),
  toggleMaximize: vi.fn().mockResolvedValue(undefined),
  startDragging: vi.fn().mockResolvedValue(undefined),
  close: vi.fn().mockResolvedValue(undefined),
});

describe("WindowChrome", () => {
  it("does not expose nonfunctional chrome in the browser preview", () => {
    const { container } = render(<WindowChrome mini={false} port={null} />);
    expect(container).toBeEmptyDOMElement();
  });
  it("delegates buttons and refreshes the real maximize state", async () => {
    const port = createPort();
    render(<WindowChrome mini={false} port={port} />);
    await act(async () => { fireEvent.click(screen.getByRole("button", { name: "最小化窗口" })); });
    expect(port.minimize).toHaveBeenCalledOnce();
    port.isMaximized.mockResolvedValue(true);
    await act(async () => { fireEvent.click(screen.getByRole("button", { name: "最大化窗口" })); });
    expect(port.toggleMaximize).toHaveBeenCalledOnce();
    expect(screen.getByRole("button", { name: "还原窗口" })).toBeInTheDocument();
    await act(async () => { fireEvent.click(screen.getByRole("button", { name: "关闭窗口" })); });
    expect(port.close).toHaveBeenCalledOnce();
    expect(port.startDragging).not.toHaveBeenCalled();
  });
  it("supports dragging and double-click, but ignores the right mouse button", async () => {
    const port = createPort();
    render(<WindowChrome mini={false} port={port} />);
    const drag = screen.getByTitle("拖动窗口；双击最大化或还原");
    await act(async () => { fireEvent.mouseDown(drag, { button: 0, detail: 1 }); });
    expect(port.startDragging).toHaveBeenCalledOnce();
    await act(async () => { fireEvent.mouseDown(drag, { button: 0, detail: 2 }); });
    expect(port.toggleMaximize).toHaveBeenCalledOnce();
    fireEvent.mouseDown(drag, { button: 2, detail: 1 });
    expect(port.startDragging).toHaveBeenCalledOnce();
  });
  it("disables maximize in mini and retains a return action", async () => {
    const port = createPort();
    const restore = vi.fn();
    render(<WindowChrome mini port={port} onRestoreMain={restore} />);
    await act(async () => { fireEvent.click(screen.getByRole("button", { name: "最大化窗口" })); });
    expect(port.toggleMaximize).not.toHaveBeenCalled();
    expect(screen.getByRole("button", { name: "最大化窗口" })).toBeDisabled();
    fireEvent.click(screen.getByRole("button", { name: "返回主窗口" }));
    expect(restore).toHaveBeenCalledOnce();
  });
  it("reports failures and allows retry without an unhandled rejection", async () => {
    const port = createPort();
    port.minimize.mockRejectedValueOnce(new Error("denied"));
    render(<WindowChrome mini={false} port={port} />);
    fireEvent.click(screen.getByRole("button", { name: "最小化窗口" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("窗口操作失败");
    await act(async () => { fireEvent.click(screen.getByRole("button", { name: "最小化窗口" })); });
    expect(screen.queryByRole("alert")).not.toBeInTheDocument();
  });
  it("tracks OS resize and removes the listener on unmount", async () => {
    const port = createPort();
    const { unmount } = render(<WindowChrome mini={false} port={port} />);
    await waitFor(() => expect(port.isMaximized).toHaveBeenCalledOnce());
    port.isMaximized.mockResolvedValue(true);
    await act(async () => { fireEvent.resize(window); });
    expect(screen.getByRole("button", { name: "还原窗口" })).toBeInTheDocument();
    unmount();
    const calls = port.isMaximized.mock.calls.length;
    fireEvent.resize(window);
    expect(port.isMaximized).toHaveBeenCalledTimes(calls);
  });
});
