import { useEffect, useRef, useState, type ReactNode } from "react";
import { heniThemes } from "../shell/theme";
import { InterfaceIcon } from "../../components/InterfaceIcon";

import type {
  SettingsSnapshot,
  SettingsUpdate,
} from "../../contracts/settings";

export interface PreferencesControlProps {
  settings: SettingsSnapshot;
  busy: boolean;
  errorMessage?: string | undefined;
  onUpdate(request: SettingsUpdate): void;
  appearanceControls?: ReactNode;
  appearanceIssue?: boolean;
}

export const PreferencesControl = ({
  settings,
  busy,
  errorMessage,
  onUpdate,
  appearanceControls,
  appearanceIssue = false,
}: PreferencesControlProps) => {
  const panel = useRef<HTMLDetailsElement>(null);
  const [section, setSection] = useState<"appearance" | "import">("appearance");
  const close = () => {
    if (panel.current === null) return;
    panel.current.open = false;
    panel.current.querySelector("summary")?.focus();
  };
  useEffect(() => {
    const dismiss = (event: PointerEvent) => {
      if (event.target instanceof Node && !panel.current?.contains(event.target) && panel.current !== null) {
        panel.current.open = false;
      }
    };
    const dismissWithEscape = (event: KeyboardEvent) => {
      if (event.key !== "Escape" || event.defaultPrevented || !panel.current?.open) return;
      event.preventDefault();
      panel.current.open = false;
      panel.current.querySelector("summary")?.focus();
    };
    document.addEventListener("pointerdown", dismiss);
    document.addEventListener("keydown", dismissWithEscape);
    return () => {
      document.removeEventListener("pointerdown", dismiss);
      document.removeEventListener("keydown", dismissWithEscape);
    };
  }, []);
  return (
  <details
    ref={panel}
    className="preferences-control"
    data-error={
      errorMessage === undefined && !appearanceIssue ? undefined : "true"
    }
  >
    <summary
      title={errorMessage !== undefined || appearanceIssue ? "设置 · 有待处理事项" : "设置"}
      aria-label={
        appearanceControls !== undefined
          ? errorMessage !== undefined || appearanceIssue
            ? "打开设置，有待处理事项"
            : "打开设置"
          : errorMessage === undefined
            ? "打开扫描与导入设置"
            : "打开扫描与导入设置，设置未保存"
      }
    >
      <InterfaceIcon name="settings" />
      {(errorMessage !== undefined || appearanceIssue) && (
        <span className="preferences-control__issue" aria-hidden="true" />
      )}
    </summary>
    <div className="preferences-control__panel">
      <header className="preferences-control__heading">
        <div><h2>设置</h2></div>
        <button type="button" onClick={close} aria-label="关闭设置" title="关闭设置"><InterfaceIcon name="close" /></button>
      </header>
      <div className="preferences-control__navigation" role="group" aria-label="设置分区">
        <button type="button" aria-pressed={section === "appearance"} onClick={() => setSection("appearance")}>
          <InterfaceIcon name="image" />外观{appearanceIssue && <span aria-label="外观有待处理事项">·</span>}
        </button>
        <button type="button" aria-pressed={section === "import"} onClick={() => setSection("import")}>
          <InterfaceIcon name="songs" />导入
        </button>
      </div>
      {errorMessage !== undefined && (
        <p className="preferences-control__error preferences-control__save-error" role="status">{errorMessage}</p>
      )}
      <div className="preferences-control__body">
      <section className="preferences-control__appearance" aria-label="外观设置" hidden={section !== "appearance"} inert={section !== "appearance"}>
      <fieldset className="theme-palette" disabled={busy}>
        <legend>色彩风格</legend>
        <div className="theme-palette__grid">
          {heniThemes.map((theme) => (
            <button type="button" key={theme.id} aria-pressed={settings.themeId === theme.id}
              aria-label={`使用${theme.label}主题`} onClick={() => onUpdate({ themeId: theme.id })}>
              <span className="theme-palette__sample" aria-hidden="true" style={{ background: `linear-gradient(135deg, ${theme.colors})` }} />
              <span>{theme.label}</span>
              <span aria-hidden="true">{settings.themeId === theme.id && <InterfaceIcon name="check" />}</span>
            </button>
          ))}
        </div>
      </fieldset>
      <div className="preferences-control__sections">
      {appearanceControls !== undefined && (
        <section aria-label="场景外观">{appearanceControls}</section>
      )}
      </div>
      </section>
      <fieldset disabled={busy} hidden={section !== "import"} inert={section !== "import"}>
        <legend>扫描与导入</legend>
        <label>
          <input
            type="checkbox"
            checked={settings.recursiveScan}
            onChange={(event) =>
              onUpdate({ recursiveScan: event.currentTarget.checked })
            }
          />
          扫描子文件夹
        </label>
        <label>
          <input
            type="checkbox"
            checked={settings.includeVideo}
            onChange={(event) =>
              onUpdate({ includeVideo: event.currentTarget.checked })
            }
          />
          扫描视频文件
        </label>
        <p>导入只收录媒体，不改变当前队列。选择歌曲、视频或歌单后，再开始播放。</p>
      </fieldset>
      </div>
    </div>
  </details>
);
};
