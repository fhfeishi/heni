import { useEffect, useRef, useState } from "react";
import { InterfaceIcon } from "../../components/InterfaceIcon";
import { nativeWindowChrome, type WindowChromePort } from "../../infrastructure/tauri/windowChrome";

export const WindowChrome = ({ mini, onRestoreMain, busy = false, port = nativeWindowChrome }: {
  mini: boolean;
  onRestoreMain?(): void;
  busy?: boolean;
  port?: WindowChromePort | null;
}) => {
  const [maximized, setMaximized] = useState(false);
  const [error, setError] = useState(false);
  const pending = useRef(false);
  const generation = useRef(0);

  useEffect(() => {
    const current = ++generation.current;
    let request = 0;
    const refresh = () => {
      const latest = ++request;
      void port?.isMaximized().then((value) => {
        if (generation.current === current && request === latest) setMaximized(value);
      }).catch(() => {
        if (generation.current === current && request === latest) setError(true);
      });
    };
    refresh();
    // WebView resize also covers OS shortcuts and monitor/window-mode changes.
    window.addEventListener("resize", refresh);
    return () => {
      generation.current = current + 1;
      window.removeEventListener("resize", refresh);
    };
  }, [port]);

  const run = async (action: () => Promise<void>) => {
    if (pending.current || port === null) return;
    pending.current = true;
    const current = generation.current;
    setError(false);
    try {
      await action();
      const value = await port.isMaximized();
      if (generation.current === current) setMaximized(value);
    } catch {
      if (generation.current === current) setError(true);
    } finally {
      pending.current = false;
    }
  };

  if (port === null) return null;
  return <header className="window-chrome" aria-label="窗口控制">
    <div className="window-chrome__drag" title="拖动窗口；双击最大化或还原"
      onMouseDown={(event) => {
        if (event.button !== 0) return;
        if (event.detail === 2) {
          if (!mini) void run(() => port.toggleMaximize());
        } else void run(() => port.startDragging());
      }}>
      <span className="window-chrome__wordmark">heni</span>
    </div>
    {error && <span className="window-chrome__error" role="alert">窗口操作失败，请重试（Alt+F4 可关闭）</span>}
    <div className="window-chrome__actions">
      {mini && onRestoreMain && <button type="button" aria-label="返回主窗口" title="返回主窗口"
        disabled={busy} onClick={onRestoreMain}><InterfaceIcon name="expand" /></button>}
      <button type="button" aria-label="最小化窗口" title="最小化" onClick={() => void run(() => port.minimize())}>
        <InterfaceIcon name="minimize" />
      </button>
      <button type="button" aria-label={maximized ? "还原窗口" : "最大化窗口"}
        title={mini ? "迷你播放器保持紧凑尺寸" : maximized ? "还原" : "最大化"}
        disabled={mini} onClick={() => void run(() => port.toggleMaximize())}>
        <InterfaceIcon name={maximized ? "restore" : "maximize"} />
      </button>
      <button type="button" className="window-chrome__close" aria-label="关闭窗口" title="关闭"
        onClick={() => void run(() => port.close())}>
        <InterfaceIcon name="close" />
      </button>
    </div>
  </header>;
};
